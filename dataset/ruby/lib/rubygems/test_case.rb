
begin
  gem 'minitest', '~> 4.0'
rescue NoMethodError, Gem::LoadError
end

if defined? Gem::QuickLoader
  Gem::QuickLoader.load_full_rubygems_library
else
  require 'rubygems'
end

begin
  gem 'minitest'
rescue Gem::LoadError
end

unless Gem::Dependency.new('rdoc', '>= 3.10').matching_specs.empty?
  gem 'rdoc'
  gem 'json'
end

require 'minitest/autorun'

require 'rubygems/deprecate'

require 'fileutils'
require 'pathname'
require 'pp'
require 'rubygems/package'
require 'shellwords'
require 'tmpdir'
require 'uri'
require 'zlib'

Gem.load_yaml

require 'rubygems/mock_gem_ui'

module Gem


  def self.searcher=(searcher)
    @searcher = searcher
  end


  def self.win_platform=(val)
    @@win_platform = val
  end


  def self.ruby= ruby
    @ruby = ruby
  end


  module DefaultUserInteraction
    @ui = Gem::MockGemUi.new
  end
end


class Gem::TestCase < MiniTest::Unit::TestCase

  attr_accessor :fetcher # :nodoc:

  attr_accessor :gem_repo # :nodoc:

  attr_accessor :uri # :nodoc:

  def assert_activate expected, *specs
    specs.each do |spec|
      case spec
      when String then
        Gem::Specification.find_by_name(spec).activate
      when Gem::Specification then
        spec.activate
      else
        flunk spec.inspect
      end
    end

    loaded = Gem.loaded_specs.values.map(&:full_name)

    assert_equal expected.sort, loaded.sort if expected
  end

  def assert_path_exists path, msg = nil
    msg = message(msg) { "Expected path '#{path}' to exist" }
    assert File.exist?(path), msg
  end


  def enable_shared value
    enable_shared = RbConfig::CONFIG['ENABLE_SHARED']
    RbConfig::CONFIG['ENABLE_SHARED'] = value

    yield
  ensure
    if enable_shared then
      RbConfig::CONFIG['enable_shared'] = enable_shared
    else
      RbConfig::CONFIG.delete 'enable_shared'
    end
  end

  def refute_path_exists path, msg = nil
    msg = message(msg) { "Expected path '#{path}' to not exist" }
    refute File.exist?(path), msg
  end

  def scan_make_command_lines(output)
    output.scan(/^#{Regexp.escape make_command}(?:[[:blank:]].*)?$/)
  end

  def parse_make_command_line(line)
    command, *args = line.shellsplit

    targets = []
    macros = {}

    args.each do |arg|
      case arg
      when /\A(\w+)=/
        macros[$1] = $'
      else
        targets << arg
      end
    end

    targets << '' if targets.empty?

    {
      :command => command,
      :targets => targets,
      :macros => macros,
    }
  end

  def assert_contains_make_command(target, output, msg = nil)
    if output.match(/\n/)
      msg = message(msg) {
        'Expected output containing make command "%s": %s' % [
          ('%s %s' % [make_command, target]).rstrip,
          output.inspect
        ]
      }
    else
      msg = message(msg) {
        'Expected make command "%s": %s' % [
          ('%s %s' % [make_command, target]).rstrip,
          output.inspect
        ]
      }
    end

    assert scan_make_command_lines(output).any? { |line|
      make = parse_make_command_line(line)

      if make[:targets].include?(target)
        yield make, line if block_given?
        true
      else
        false
      end
    }, msg
  end

  include Gem::DefaultUserInteraction

  undef_method :default_test if instance_methods.include? 'default_test' or
                                instance_methods.include? :default_test

  @@project_dir = Dir.pwd.untaint unless defined?(@@project_dir)

  @@initial_reset = false


  def setup
    super

    @orig_gem_home   = ENV['GEM_HOME']
    @orig_gem_path   = ENV['GEM_PATH']
    @orig_gem_vendor = ENV['GEM_VENDOR']

    ENV['GEM_VENDOR'] = nil

    @current_dir = Dir.pwd
    @fetcher     = nil
    @ui          = Gem::MockGemUi.new

    tmpdir = File.expand_path Dir.tmpdir
    tmpdir.untaint

    if ENV['KEEP_FILES'] then
      @tempdir = File.join(tmpdir, "test_rubygems_#{$$}.#{Time.now.to_i}")
    else
      @tempdir = File.join(tmpdir, "test_rubygems_#{$$}")
    end
    @tempdir.untaint

    FileUtils.mkdir_p @tempdir

    Dir.chdir @tempdir do
      @tempdir = File.expand_path '.'
      @tempdir.untaint
    end

    @gemhome  = File.join @tempdir, 'gemhome'
    @userhome = File.join @tempdir, 'userhome'
    ENV["GEM_SPEC_CACHE"] = File.join @tempdir, 'spec_cache'

    @orig_ruby = if ENV['RUBY'] then
                   ruby = Gem.ruby
                   Gem.ruby = ENV['RUBY']
                   ruby
                 end

    @git = ENV['GIT'] || 'git'

    Gem.ensure_gem_subdirectories @gemhome

    @orig_LOAD_PATH = $LOAD_PATH.dup
    $LOAD_PATH.map! { |s| File.expand_path(s).untaint }

    Dir.chdir @tempdir

    @orig_ENV_HOME = ENV['HOME']
    ENV['HOME'] = @userhome
    #nodyna <instance_variable_set-2294> <not yet classified>
    Gem.instance_variable_set :@user_home, nil
    #nodyna <send-2295> <SD EASY (private methods)>
    Gem.send :remove_instance_variable, :@ruby_version if
      Gem.instance_variables.include? :@ruby_version

    FileUtils.mkdir_p @gemhome
    FileUtils.mkdir_p @userhome

    @orig_gem_private_key_passphrase = ENV['GEM_PRIVATE_KEY_PASSPHRASE']
    ENV['GEM_PRIVATE_KEY_PASSPHRASE'] = PRIVATE_KEY_PASSPHRASE

    @default_dir = File.join @tempdir, 'default'
    @default_spec_dir = File.join @default_dir, "specifications", "default"
    #nodyna <instance_variable_set-2296> <not yet classified>
    Gem.instance_variable_set :@default_dir, @default_dir
    FileUtils.mkdir_p @default_spec_dir

    if @@initial_reset
      Gem::Specification.unresolved_deps.clear # done to avoid cross-test warnings
    else
      @@initial_reset = true
      Gem::Specification.reset
    end
    Gem.use_paths(@gemhome)

    Gem::Security.reset

    Gem.loaded_specs.clear
    Gem.clear_default_specs
    Gem::Specification.unresolved_deps.clear

    Gem.configuration.verbose = true
    Gem.configuration.update_sources = true

    Gem::RemoteFetcher.fetcher = Gem::FakeFetcher.new

    @gem_repo = "http://gems.example.com/"
    @uri = URI.parse @gem_repo
    Gem.sources.replace [@gem_repo]

    Gem.searcher = nil
    Gem::SpecFetcher.fetcher = nil
    @orig_BASERUBY = RbConfig::CONFIG['BASERUBY']
    RbConfig::CONFIG['BASERUBY'] = RbConfig::CONFIG['ruby_install_name']

    @orig_arch = RbConfig::CONFIG['arch']

    if win_platform?
      util_set_arch 'i386-mswin32'
    else
      util_set_arch 'i686-darwin8.10.1'
    end

    @marshal_version = "#{Marshal::MAJOR_VERSION}.#{Marshal::MINOR_VERSION}"
  end


  def teardown
    $LOAD_PATH.replace @orig_LOAD_PATH if @orig_LOAD_PATH

    if @orig_BASERUBY
      RbConfig::CONFIG['BASERUBY'] = @orig_BASERUBY
    else
      RbConfig::CONFIG.delete('BASERUBY')
    end
    RbConfig::CONFIG['arch'] = @orig_arch

    if defined? Gem::RemoteFetcher then
      Gem::RemoteFetcher.fetcher = nil
    end

    Dir.chdir @current_dir

    FileUtils.rm_rf @tempdir unless ENV['KEEP_FILES']

    ENV['GEM_HOME']   = @orig_gem_home
    ENV['GEM_PATH']   = @orig_gem_path
    ENV['GEM_VENDOR'] = @orig_gem_vendor

    Gem.ruby = @orig_ruby if @orig_ruby

    if @orig_ENV_HOME then
      ENV['HOME'] = @orig_ENV_HOME
    else
      ENV.delete 'HOME'
    end

    #nodyna <instance_variable_set-2297> <not yet classified>
    Gem.instance_variable_set :@default_dir, nil

    ENV['GEM_PRIVATE_KEY_PASSPHRASE'] = @orig_gem_private_key_passphrase

    Gem::Specification._clear_load_cache
  end

  def common_installer_setup
    common_installer_teardown

    Gem.post_build do |installer|
      @post_build_hook_arg = installer
      true
    end

    Gem.post_install do |installer|
      @post_install_hook_arg = installer
    end

    Gem.post_uninstall do |uninstaller|
      @post_uninstall_hook_arg = uninstaller
    end

    Gem.pre_install do |installer|
      @pre_install_hook_arg = installer
      true
    end

    Gem.pre_uninstall do |uninstaller|
      @pre_uninstall_hook_arg = uninstaller
    end
  end

  def common_installer_teardown
    Gem.post_build_hooks.clear
    Gem.post_install_hooks.clear
    Gem.done_installing_hooks.clear
    Gem.post_reset_hooks.clear
    Gem.post_uninstall_hooks.clear
    Gem.pre_install_hooks.clear
    Gem.pre_reset_hooks.clear
    Gem.pre_uninstall_hooks.clear
  end


  def git_gem name = 'a', version = 1
    have_git?

    directory = File.join 'git', name
    directory = File.expand_path directory

    git_spec = Gem::Specification.new name, version do |specification|
      yield specification if block_given?
    end

    FileUtils.mkdir_p directory

    gemspec = "#{name}.gemspec"

    open File.join(directory, gemspec), 'w' do |io|
      io.write git_spec.to_ruby
    end

    head = nil

    Dir.chdir directory do
      unless File.exist? '.git' then
        system @git, 'init', '--quiet'
        system @git, 'config', 'user.name',  'RubyGems Tests'
        system @git, 'config', 'user.email', 'rubygems@example'
      end

      system @git, 'add', gemspec
      system @git, 'commit', '-a', '-m', 'a non-empty commit message', '--quiet'
      head = Gem::Util.popen('git', 'rev-parse', 'master').strip
    end

    return name, git_spec.version, directory, head
  end


  def have_git?
    return if in_path? @git

    skip 'cannot find git executable, use GIT environment variable to set'
  end

  def in_path? executable # :nodoc:
    return true if %r%\A([A-Z]:|/)% =~ executable and File.exist? executable

    ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
      File.exist? File.join directory, executable
    end
  end


  def install_gem spec, options = {}
    require 'rubygems/installer'

    gem = File.join @tempdir, "gems", "#{spec.full_name}.gem"

    unless File.exist? gem then
      use_ui Gem::MockGemUi.new do
        Dir.chdir @tempdir do
          Gem::Package.build spec
        end
      end

      gem = File.join(@tempdir, File.basename(spec.cache_file)).untaint
    end

    Gem::Installer.new(gem, options.merge({:wrappers => true})).install
  end


  def install_gem_user spec
    install_gem spec, :user_install => true
  end

  def uninstall_gem spec
    require 'rubygems/uninstaller'

    Gem::Uninstaller.new(spec.name,
                         :executables => true, :user_install => true).uninstall
  end


  def create_tmpdir
    tmpdir = nil
    Dir.chdir Dir.tmpdir do tmpdir = Dir.pwd end # HACK OSX /private/tmp
    tmpdir = File.join tmpdir, "test_rubygems_#{$$}"
    FileUtils.mkdir_p tmpdir
    return tmpdir
  end


  def mu_pp(obj)
    s = ''
    s = PP.pp obj, s
    s = s.force_encoding(Encoding.default_external) if defined? Encoding
    s.chomp
  end


  def read_cache(path)
    open path.dup.untaint, 'rb' do |io|
      Marshal.load io.read
    end
  end


  def read_binary(path)
    Gem.read_binary path
  end


  def write_file(path)
    path = File.join @gemhome, path unless Pathname.new(path).absolute?
    dir = File.dirname path
    FileUtils.mkdir_p dir

    open path, 'wb' do |io|
      yield io if block_given?
    end

    path
  end

  def all_spec_names
    Gem::Specification.map(&:full_name)
  end


  def quick_gem(name, version='2')
    require 'rubygems/specification'

    spec = Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      yield(s) if block_given?
    end

    Gem::Specification.map # HACK: force specs to (re-)load before we write

    written_path = write_file spec.spec_file do |io|
      io.write spec.to_ruby_for_cache
    end

    spec.loaded_from = spec.loaded_from = written_path

    Gem::Specification.add_spec spec.for_cache

    return spec
  end


  def quick_spec name, version = '2' # :nodoc:
    util_spec name, version
  end


  def util_build_gem(spec)
    dir = spec.gem_dir
    FileUtils.mkdir_p dir

    Dir.chdir dir do
      spec.files.each do |file|
        next if File.exist? file
        FileUtils.mkdir_p File.dirname(file)
        File.open file, 'w' do |fp| fp.puts "# #{file}" end
      end

      use_ui Gem::MockGemUi.new do
        Gem::Package.build spec
      end

      cache = spec.cache_file
      FileUtils.mv File.basename(cache), cache
    end
  end

  def util_remove_gem(spec)
    FileUtils.rm_rf spec.cache_file
    FileUtils.rm_rf spec.spec_file
  end


  def util_clear_gems
    FileUtils.rm_rf File.join(@gemhome, "gems") # TODO: use Gem::Dirs
    FileUtils.mkdir File.join(@gemhome, "gems")
    FileUtils.rm_rf File.join(@gemhome, "specifications")
    FileUtils.mkdir File.join(@gemhome, "specifications")
    Gem::Specification.reset
  end


  def install_specs(*specs)
    Gem::Specification.add_specs(*specs)
    Gem.searcher = nil
  end


  def install_default_gems(*specs)
    install_default_specs(*specs)

    specs.each do |spec|
      open spec.loaded_from, 'w' do |io|
        io.write spec.to_ruby_for_cache
      end
    end
  end


  def install_default_specs(*specs)
    install_specs(*specs)
    specs.each do |spec|
      Gem.register_default_spec(spec)
    end
  end

  def loaded_spec_names
    Gem.loaded_specs.values.map(&:full_name).sort
  end

  def unresolved_names
    Gem::Specification.unresolved_deps.values.map(&:to_s).sort
  end

  def save_loaded_features
    old_loaded_features = $LOADED_FEATURES.dup
    yield
  ensure
    $LOADED_FEATURES.replace old_loaded_features
  end


  def new_spec name, version, deps = nil, *files # :nodoc:
    require 'rubygems/specification'

    spec = Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      Array(deps).each do |n, req|
        s.add_dependency n, (req || '>= 0')
      end

      s.files.push(*files) unless files.empty?

      yield s if block_given?
    end

    spec.loaded_from = spec.spec_file

    unless files.empty? then
      write_file spec.spec_file do |io|
        io.write spec.to_ruby_for_cache
      end

      util_build_gem spec

      cache_file = File.join @tempdir, 'gems', "#{spec.full_name}.gem"
      FileUtils.mkdir_p File.dirname cache_file
      FileUtils.mv spec.cache_file, cache_file
      FileUtils.rm spec.spec_file
    end

    spec
  end

  def new_default_spec(name, version, deps = nil, *files)
    spec = util_spec name, version, deps

    spec.loaded_from = File.join(@default_spec_dir, spec.spec_name)
    spec.files = files

    lib_dir = File.join(@tempdir, "default_gems", "lib")
    $LOAD_PATH.unshift(lib_dir)
    files.each do |file|
      rb_path = File.join(lib_dir, file)
      FileUtils.mkdir_p(File.dirname(rb_path))
      File.open(rb_path, "w") do |rb|
        rb << "# #{file}"
      end
    end

    spec
  end


  def util_spec name, version = 2, deps = nil # :yields: specification
    raise "deps or block, not both" if deps and block_given?

    spec = Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      yield s if block_given?
    end

    if deps then
      deps.keys.sort.each do |n|
        spec.add_dependency n, (deps[n] || '>= 0')
      end
    end

    spec.loaded_from = spec.spec_file

    Gem::Specification.add_spec spec

    return spec
  end


  def util_gem(name, version, deps = nil, &block)
    raise "deps or block, not both" if deps and block

    if deps then
      block = proc do |s|
        deps.keys.sort.each do |n|
          s.add_dependency n, (deps[n] || '>= 0')
        end
      end
    end

    spec = quick_gem(name, version, &block)

    util_build_gem spec

    cache_file = File.join @tempdir, 'gems', "#{spec.original_name}.gem"
    FileUtils.mkdir_p File.dirname cache_file
    FileUtils.mv spec.cache_file, cache_file
    FileUtils.rm spec.spec_file

    spec.loaded_from = nil

    [spec, cache_file]
  end


  def util_gzip(data)
    out = StringIO.new

    Zlib::GzipWriter.wrap out do |io|
      io.write data
    end

    out.string
  end


  def util_make_gems(prerelease = false)
    @a1 = quick_gem 'a', '1' do |s|
      s.files = %w[lib/code.rb]
      s.require_paths = %w[lib]
      s.date = Gem::Specification::TODAY - 86400
      s.homepage = 'http://a.example.com'
      s.email = %w[example@example.com example2@example.com]
      s.authors = %w[Example Example2]
      s.description = <<-DESC
This line is really, really long.  So long, in fact, that it is more than eighty characters long!  The purpose of this line is for testing wrapping behavior because sometimes people don't wrap their text to eighty characters.  Without the wrapping, the text might not look good in the RSS feed.

Also, a list:
  * An entry that\'s actually kind of sort
  * an entry that\'s really long, which will probably get wrapped funny.  That's ok, somebody wasn't thinking straight when they made it more than eighty characters.
      DESC
    end

    init = proc do |s|
      s.files = %w[lib/code.rb]
      s.require_paths = %w[lib]
    end

    @a2      = quick_gem('a', '2',      &init)
    @a3a     = quick_gem('a', '3.a',    &init)
    @a_evil9 = quick_gem('a_evil', '9', &init)
    @b2      = quick_gem('b', '2',      &init)
    @c1_2    = quick_gem('c', '1.2',    &init)
    @x       = quick_gem('x', '1',      &init)
    @dep_x   = quick_gem('dep_x', '1') do |s|
      s.files = %w[lib/code.rb]
      s.require_paths = %w[lib]
      s.add_dependency 'x', '>= 1'
    end

    @pl1     = quick_gem 'pl', '1' do |s| # l for legacy
      s.files = %w[lib/code.rb]
      s.require_paths = %w[lib]
      s.platform = Gem::Platform.new 'i386-linux'
      #nodyna <instance_variable_set-2298> <not yet classified>
      s.instance_variable_set :@original_platform, 'i386-linux'
    end

    if prerelease
      @a2_pre = quick_gem('a', '2.a', &init)
      write_file File.join(*%W[gems #{@a2_pre.original_name} lib code.rb])
      util_build_gem @a2_pre
    end

    write_file File.join(*%W[gems #{@a1.original_name}      lib code.rb])
    write_file File.join(*%W[gems #{@a2.original_name}      lib code.rb])
    write_file File.join(*%W[gems #{@a3a.original_name}     lib code.rb])
    write_file File.join(*%W[gems #{@a_evil9.original_name} lib code.rb])
    write_file File.join(*%W[gems #{@b2.original_name}      lib code.rb])
    write_file File.join(*%W[gems #{@c1_2.original_name}    lib code.rb])
    write_file File.join(*%W[gems #{@pl1.original_name}     lib code.rb])
    write_file File.join(*%W[gems #{@x.original_name}       lib code.rb])
    write_file File.join(*%W[gems #{@dep_x.original_name}   lib code.rb])

    [@a1, @a2, @a3a, @a_evil9, @b2, @c1_2, @pl1, @x, @dep_x].each do |spec|
      util_build_gem spec
    end

    FileUtils.rm_r File.join(@gemhome, "gems", @pl1.original_name)
  end


  def util_set_arch(arch)
    RbConfig::CONFIG['arch'] = arch
    platform = Gem::Platform.new arch

    #nodyna <instance_variable_set-2299> <not yet classified>
    Gem.instance_variable_set :@platforms, nil
    #nodyna <instance_variable_set-2300> <not yet classified>
    Gem::Platform.instance_variable_set :@local, nil

    platform
  end


  def util_setup_fake_fetcher(prerelease = false)
    require 'zlib'
    require 'socket'
    require 'rubygems/remote_fetcher'

    @fetcher = Gem::FakeFetcher.new

    util_make_gems(prerelease)
    Gem::Specification.reset

    @all_gems = [@a1, @a2, @a3a, @a_evil9, @b2, @c1_2].sort
    @all_gem_names = @all_gems.map { |gem| gem.full_name }

    gem_names = [@a1.full_name, @a2.full_name, @a3a.full_name, @b2.full_name]
    @gem_names = gem_names.sort.join("\n")

    Gem::RemoteFetcher.fetcher = @fetcher
  end


  def add_to_fetcher(spec, path=nil, repo=@gem_repo)
    path ||= spec.cache_file
    @fetcher.data["#{@gem_repo}gems/#{spec.file_name}"] = read_binary(path)
  end


  def util_setup_spec_fetcher(*specs)
    specs -= Gem::Specification._all
    Gem::Specification.add_specs(*specs)

    spec_fetcher = Gem::SpecFetcher.fetcher

    prerelease, all = Gem::Specification.partition { |spec|
      spec.version.prerelease?
    }

    spec_fetcher.specs[@uri] = []
    all.each do |spec|
      spec_fetcher.specs[@uri] << spec.name_tuple
    end

    spec_fetcher.latest_specs[@uri] = []
    Gem::Specification.latest_specs.each do |spec|
      spec_fetcher.latest_specs[@uri] << spec.name_tuple
    end

    spec_fetcher.prerelease_specs[@uri] = []
    prerelease.each do |spec|
      spec_fetcher.prerelease_specs[@uri] << spec.name_tuple
    end

    unless Gem::RemoteFetcher === @fetcher then
      v = Gem.marshal_version

      specs = all.map { |spec| spec.name_tuple }
      s_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic specs

      latest_specs = Gem::Specification.latest_specs.map do |spec|
        spec.name_tuple
      end

      l_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic latest_specs

      prerelease_specs = prerelease.map { |spec| spec.name_tuple }
      p_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic prerelease_specs

      @fetcher.data["#{@gem_repo}specs.#{v}.gz"]            = s_zip
      @fetcher.data["#{@gem_repo}latest_specs.#{v}.gz"]     = l_zip
      @fetcher.data["#{@gem_repo}prerelease_specs.#{v}.gz"] = p_zip

      v = Gem.marshal_version

      Gem::Specification.each do |spec|
        path = "#{@gem_repo}quick/Marshal.#{v}/#{spec.original_name}.gemspec.rz"
        data = Marshal.dump spec
        data_deflate = Zlib::Deflate.deflate data
        @fetcher.data[path] = data_deflate
      end
    end

    nil # force errors
  end


  def util_zip(data)
    Zlib::Deflate.deflate data
  end

  def util_set_RUBY_VERSION(version, patchlevel = nil, revision = nil)
    if Gem.instance_variables.include? :@ruby_version or
       Gem.instance_variables.include? '@ruby_version' then
      #nodyna <send-2301> <SD MODERATE (private methods)>
      Gem.send :remove_instance_variable, :@ruby_version
    end

    @RUBY_VERSION    = RUBY_VERSION
    @RUBY_PATCHLEVEL = RUBY_PATCHLEVEL if defined?(RUBY_PATCHLEVEL)
    @RUBY_REVISION   = RUBY_REVISION   if defined?(RUBY_REVISION)
    #nodyna <send-2302> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_VERSION
    #nodyna <send-2303> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_PATCHLEVEL if defined?(RUBY_PATCHLEVEL)
    #nodyna <send-2304> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_REVISION   if defined?(RUBY_REVISION)

    #nodyna <const_set-2305> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_VERSION,    version
    #nodyna <const_set-2306> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_PATCHLEVEL, patchlevel if patchlevel
    #nodyna <const_set-2307> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_REVISION,   revision   if revision
  end

  def util_restore_RUBY_VERSION
    #nodyna <send-2308> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_VERSION
    #nodyna <send-2309> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_PATCHLEVEL if defined?(RUBY_PATCHLEVEL)
    #nodyna <send-2310> <SD MODERATE (private methods)>
    Object.send :remove_const, :RUBY_REVISION   if defined?(RUBY_REVISION)

    #nodyna <const_set-2311> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_VERSION,    @RUBY_VERSION
    #nodyna <const_set-2312> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_PATCHLEVEL, @RUBY_PATCHLEVEL if
      defined?(@RUBY_PATCHLEVEL)
    #nodyna <const_set-2313> <CS TRIVIAL (static values)>
    Object.const_set :RUBY_REVISION,   @RUBY_REVISION   if
      defined?(@RUBY_REVISION)
  end


  def self.win_platform?
    Gem.win_platform?
  end


  def win_platform?
    Gem.win_platform?
  end


  def self.vc_windows?
    RUBY_PLATFORM.match('mswin')
  end


  def vc_windows?
    RUBY_PLATFORM.match('mswin')
  end


  def self.make_command
    ENV["make"] || (vc_windows? ? 'nmake' : 'make')
  end


  def make_command
    ENV["make"] || (vc_windows? ? 'nmake' : 'make')
  end


  def nmake_found?
    system('nmake /? 1>NUL 2>&1')
  end

  def wait_for_child_process_to_exit
    Process.wait if Process.respond_to?(:fork)
  rescue Errno::ECHILD
  end


  def self.process_based_port
    @@process_based_port ||= 8000 + $$ % 1000
  end


  def process_based_port
    self.class.process_based_port
  end


  def build_rake_in(good=true)
    gem_ruby = Gem.ruby
    Gem.ruby = @@ruby
    env_rake = ENV["rake"]
    rake = (good ? @@good_rake : @@bad_rake)
    ENV["rake"] = rake
    yield rake
  ensure
    Gem.ruby = gem_ruby
    if env_rake
      ENV["rake"] = env_rake
    else
      ENV.delete("rake")
    end
  end


  def self.rubybin
    ruby = ENV["RUBY"]
    return ruby if ruby
    ruby = "ruby"
    rubyexe = "#{ruby}.exe"

    3.times do
      if File.exist? ruby and File.executable? ruby and !File.directory? ruby
        return File.expand_path(ruby)
      end
      if File.exist? rubyexe and File.executable? rubyexe
        return File.expand_path(rubyexe)
      end
      ruby = File.join("..", ruby)
    end

    begin
      require "rbconfig"
      File.join(RbConfig::CONFIG["bindir"],
                RbConfig::CONFIG["ruby_install_name"] +
                RbConfig::CONFIG["EXEEXT"])
    rescue LoadError
      "ruby"
    end
  end

  @@ruby = rubybin
  @@good_rake = "#{rubybin} #{File.expand_path('../../../test/rubygems/good_rake.rb', __FILE__)}"
  @@bad_rake = "#{rubybin} #{File.expand_path('../../../test/rubygems/bad_rake.rb', __FILE__)}"


  def dep name, *requirements
    Gem::Dependency.new name, *requirements
  end


  def dependency_request dep, from_name, from_version, parent = nil
    remote = Gem::Source.new @uri

    unless parent then
      parent_dep = dep from_name, from_version
      parent = Gem::Resolver::DependencyRequest.new parent_dep, nil
    end

    spec = Gem::Resolver::IndexSpecification.new \
      nil, from_name, from_version, remote, Gem::Platform::RUBY
    activation = Gem::Resolver::ActivationRequest.new spec, parent

    Gem::Resolver::DependencyRequest.new dep, activation
  end


  def req *requirements
    return requirements.first if Gem::Requirement === requirements.first
    Gem::Requirement.create requirements
  end


  def spec name, version, &block
    Gem::Specification.new name, v(version), &block
  end


  def spec_fetcher repository = @gem_repo
    Gem::TestCase::SpecFetcherSetup.declare self, repository do |spec_fetcher_setup|
      yield spec_fetcher_setup if block_given?
    end
  end


  def v string
    Gem::Version.create string
  end


  def vendor_gem name = 'a', version = 1
    directory = File.join 'vendor', name

    vendor_spec = Gem::Specification.new name, version do |specification|
      yield specification if block_given?
    end

    FileUtils.mkdir_p directory

    open File.join(directory, "#{name}.gemspec"), 'w' do |io|
      io.write vendor_spec.to_ruby
    end

    return name, vendor_spec.version, directory
  end


  class StaticSet < Gem::Resolver::Set


    attr_accessor :remote


    def initialize(specs)
      super()

      @specs = specs

      @remote = true
    end


    def add spec
      @specs << spec
    end


    def find_spec(dep)
      @specs.reverse_each do |s|
        return s if dep.matches_spec? s
      end
    end


    def find_all(dep)
      @specs.find_all { |s| dep.match? s, @prerelease }
    end


    def load_spec name, ver, platform, source
      dep = Gem::Dependency.new name, ver
      spec = find_spec dep

      Gem::Specification.new spec.name, spec.version do |s|
        s.platform = spec.platform
      end
    end

    def prefetch reqs # :nodoc:
    end
  end


  def self.load_cert cert_name
    cert_file = cert_path cert_name

    cert = File.read cert_file

    OpenSSL::X509::Certificate.new cert
  end


  def self.cert_path cert_name
    if 32 == (Time.at(2**32) rescue 32) then
      cert_file =
        File.expand_path "../../../test/rubygems/#{cert_name}_cert_32.pem",
                         __FILE__

      return cert_file if File.exist? cert_file
    end

    File.expand_path "../../../test/rubygems/#{cert_name}_cert.pem", __FILE__
  end


  def self.load_key key_name, passphrase = nil
    key_file = key_path key_name

    key = File.read key_file

    OpenSSL::PKey::RSA.new key, passphrase
  end


  def self.key_path key_name
    File.expand_path "../../../test/rubygems/#{key_name}_key.pem", __FILE__
  end


  PRIVATE_KEY_PASSPHRASE      = 'Foo bar'

  begin
    PRIVATE_KEY                 = load_key 'private'
    PRIVATE_KEY_PATH            = key_path 'private'

    ENCRYPTED_PRIVATE_KEY       = load_key 'encrypted_private', PRIVATE_KEY_PASSPHRASE
    ENCRYPTED_PRIVATE_KEY_PATH  = key_path 'encrypted_private'

    PUBLIC_KEY                  = PRIVATE_KEY.public_key

    PUBLIC_CERT                 = load_cert 'public'
    PUBLIC_CERT_PATH            = cert_path 'public'
  rescue Errno::ENOENT
    PRIVATE_KEY = nil
    PUBLIC_KEY  = nil
    PUBLIC_CERT = nil
  end if defined?(OpenSSL::SSL)

end

require 'rubygems/test_utilities'

