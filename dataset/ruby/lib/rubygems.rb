
require 'rbconfig'
require 'thread'

module Gem
  VERSION = '2.4.5.1'
end

require 'rubygems/compatibility'

require 'rubygems/defaults'
require 'rubygems/deprecate'
require 'rubygems/errors'



module Gem
  RUBYGEMS_DIR = File.dirname File.expand_path(__FILE__)


  WIN_PATTERNS = [
    /bccwin/i,
    /cygwin/i,
    /djgpp/i,
    /mingw/i,
    /mswin/i,
    /wince/i,
  ]

  GEM_DEP_FILES = %w[
    gem.deps.rb
    Gemfile
    Isolate
  ]


  REPOSITORY_SUBDIRECTORIES = %w[
    build_info
    cache
    doc
    extensions
    gems
    specifications
  ]


  REPOSITORY_DEFAULT_GEM_SUBDIRECTORIES = %w[
    gems
    specifications/default
  ]

  @@win_platform = nil

  @configuration = nil
  @loaded_specs = {}
  LOADED_SPECS_MUTEX = Mutex.new
  @path_to_default_spec_map = {}
  @platforms = []
  @ruby = nil
  @ruby_api_version = nil
  @sources = nil

  @post_build_hooks     ||= []
  @post_install_hooks   ||= []
  @post_uninstall_hooks ||= []
  @pre_uninstall_hooks  ||= []
  @pre_install_hooks    ||= []
  @pre_reset_hooks      ||= []
  @post_reset_hooks     ||= []


  def self.try_activate path

    spec = Gem::Specification.find_inactive_by_path path

    unless spec
      spec = Gem::Specification.find_by_path path
      return true if spec && spec.activated?
      return false
    end

    begin
      spec.activate
    rescue Gem::LoadError # this could fail due to gem dep collisions, go lax
      Gem::Specification.find_by_name(spec.name).activate
    end

    return true
  end

  def self.needs
    rs = Gem::RequestSet.new

    yield rs

    finish_resolve rs
  end

  def self.finish_resolve(request_set=Gem::RequestSet.new)
    request_set.import Gem::Specification.unresolved_deps.values

    request_set.resolve_current.each do |s|
      s.full_spec.activate
    end
  end


  def self.bin_path(name, exec_name = nil, *requirements)

    raise ArgumentError, "you must supply exec_name" unless exec_name

    requirements = Gem::Requirement.default if
      requirements.empty?

    dep = Gem::Dependency.new name, requirements

    loaded = Gem.loaded_specs[name]

    return loaded.bin_file exec_name if loaded && dep.matches_spec?(loaded)

    specs = dep.matching_specs(true)

    raise Gem::GemNotFoundException,
          "can't find gem #{name} (#{requirements})" if specs.empty?

    specs = specs.find_all { |spec|
      spec.executables.include? exec_name
    } if exec_name

    unless spec = specs.last
      msg = "can't find gem #{name} (#{requirements}) with executable #{exec_name}"
      raise Gem::GemNotFoundException, msg
    end

    spec.bin_file exec_name
  end


  def self.binary_mode
    'rb'
  end


  def self.bindir(install_dir=Gem.dir)
    return File.join install_dir, 'bin' unless
      install_dir.to_s == Gem.default_dir.to_s
    Gem.default_bindir
  end


  def self.clear_paths
    @paths         = nil
    @user_home     = nil
    Gem::Specification.reset
    Gem::Security.reset if defined?(Gem::Security)
  end


  def self.config_file
    @config_file ||= File.join Gem.user_home, '.gemrc'
  end


  def self.configuration
    @configuration ||= Gem::ConfigFile.new []
  end


  def self.configuration=(config)
    @configuration = config
  end


  def self.datadir(gem_name)
    spec = @loaded_specs[gem_name]
    return nil if spec.nil?
    File.join spec.full_gem_path, "data", gem_name
  end


  def self.deflate(data)
    require 'zlib'
    Zlib::Deflate.deflate data
  end


  def self.paths
    @paths ||= Gem::PathSupport.new
  end


  def self.paths=(env)
    clear_paths
    @paths = Gem::PathSupport.new env
    Gem::Specification.dirs = @paths.path
  end


  def self.dir
    paths.home
  end

  def self.path
    paths.path
  end

  def self.spec_cache_dir
    paths.spec_cache_dir
  end


  def self.ensure_gem_subdirectories dir = Gem.dir, mode = nil
    ensure_subdirectories(dir, mode, REPOSITORY_SUBDIRECTORIES)
  end


  def self.ensure_default_gem_subdirectories dir = Gem.dir, mode = nil
    ensure_subdirectories(dir, mode, REPOSITORY_DEFAULT_GEM_SUBDIRECTORIES)
  end

  def self.ensure_subdirectories dir, mode, subdirs # :nodoc:
    old_umask = File.umask
    File.umask old_umask | 002

    require 'fileutils'

    options = {}

    options[:mode] = mode if mode

    subdirs.each do |name|
      subdir = File.join dir, name
      next if File.exist? subdir
      FileUtils.mkdir_p subdir, options rescue nil
    end
  ensure
    File.umask old_umask
  end


  def self.extension_api_version # :nodoc:
    if 'no' == RbConfig::CONFIG['ENABLE_SHARED'] then
      "#{ruby_api_version}-static"
    else
      ruby_api_version
    end
  end


  def self.find_files(glob, check_load_path=true)
    files = []

    files = find_files_from_load_path glob if check_load_path

    files.concat Gem::Specification.map { |spec|
      spec.matches_for_glob("#{glob}#{Gem.suffix_pattern}")
    }.flatten

    files.uniq! if check_load_path

    return files
  end

  def self.find_files_from_load_path glob # :nodoc:
    $LOAD_PATH.map { |load_path|
      Dir["#{File.expand_path glob, load_path}#{Gem.suffix_pattern}"]
    }.flatten.select { |file| File.file? file.untaint }
  end


  def self.find_latest_files(glob, check_load_path=true)
    files = []

    files = find_files_from_load_path glob if check_load_path

    files.concat Gem::Specification.latest_specs(true).map { |spec|
      spec.matches_for_glob("#{glob}#{Gem.suffix_pattern}")
    }.flatten

    files.uniq! if check_load_path

    return files
  end


  def self.find_home
    windows = File::ALT_SEPARATOR
    if not windows or RUBY_VERSION >= '1.9' then
      File.expand_path "~"
    else
      ['HOME', 'USERPROFILE'].each do |key|
        return File.expand_path ENV[key] if ENV[key]
      end

      if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
        File.expand_path "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
      end
    end
  rescue
    if windows then
      File.expand_path File.join(ENV['HOMEDRIVE'] || ENV['SystemDrive'], '/')
    else
      File.expand_path "/"
    end
  end

  private_class_method :find_home



  def self.gunzip(data)
    require 'rubygems/util'
    Gem::Util.gunzip data
  end


  def self.gzip(data)
    require 'rubygems/util'
    Gem::Util.gzip data
  end


  def self.inflate(data)
    require 'rubygems/util'
    Gem::Util.inflate data
  end


  def self.install name, version = Gem::Requirement.default, *options
    require "rubygems/dependency_installer"
    inst = Gem::DependencyInstaller.new(*options)
    inst.install name, version
    inst.installed_gems
  end


  def self.host
    @host ||= Gem::DEFAULT_HOST
  end


  def self.host= host
    @host = host
  end


  def self.load_path_insert_index
    index = $LOAD_PATH.index RbConfig::CONFIG['sitelibdir']

    index
  end

  @yaml_loaded = false


  def self.load_yaml
    return if @yaml_loaded
    return unless defined?(gem)

    test_syck = ENV['TEST_SYCK']

    unless test_syck
      begin
        gem 'psych', '~> 1.2', '>= 1.2.1'
      rescue Gem::LoadError
      end

      begin
        require 'psych'
      rescue ::LoadError
      else
        if defined?(YAML::ENGINE) && YAML::ENGINE.yamler != "psych"
          YAML::ENGINE.yamler = "psych"
        end

        require 'rubygems/psych_additions'
        require 'rubygems/psych_tree'
      end
    end

    require 'yaml'

    if test_syck and defined?(YAML::ENGINE)
      YAML::ENGINE.yamler = "syck" unless YAML::ENGINE.syck?
    end

    require 'rubygems/syck_hack'

    @yaml_loaded = true
  end


  def self.location_of_caller
    caller[1] =~ /(.*?):(\d+).*?$/i
    file = $1
    lineno = $2.to_i

    [file, lineno]
  end


  def self.marshal_version
    "#{Marshal::MAJOR_VERSION}.#{Marshal::MINOR_VERSION}"
  end


  def self.platforms=(platforms)
    @platforms = platforms
  end


  def self.platforms
    @platforms ||= []
    if @platforms.empty?
      @platforms = [Gem::Platform::RUBY, Gem::Platform.local]
    end
    @platforms
  end


  def self.post_build(&hook)
    @post_build_hooks << hook
  end


  def self.post_install(&hook)
    @post_install_hooks << hook
  end


  def self.done_installing(&hook)
    @done_installing_hooks << hook
  end


  def self.post_reset(&hook)
    @post_reset_hooks << hook
  end


  def self.post_uninstall(&hook)
    @post_uninstall_hooks << hook
  end


  def self.pre_install(&hook)
    @pre_install_hooks << hook
  end


  def self.pre_reset(&hook)
    @pre_reset_hooks << hook
  end


  def self.pre_uninstall(&hook)
    @pre_uninstall_hooks << hook
  end


  def self.prefix
    prefix = File.dirname RUBYGEMS_DIR

    if prefix != File.expand_path(RbConfig::CONFIG['sitelibdir']) and
       prefix != File.expand_path(RbConfig::CONFIG['libdir']) and
       'lib' == File.basename(RUBYGEMS_DIR) then
      prefix
    end
  end


  def self.refresh
    Gem::Specification.reset
  end


  def self.read_binary(path)
    open path, 'rb+' do |f|
      f.flock(File::LOCK_EX)
      f.read
    end
  rescue Errno::EACCES
    open path, 'rb' do |f|
      f.read
    end
  end


  def self.ruby
    if @ruby.nil? then
      @ruby = File.join(RbConfig::CONFIG['bindir'],
                        "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}")

      @ruby = "\"#{@ruby}\"" if @ruby =~ /\s/
    end

    @ruby
  end


  def self.ruby_api_version
    @ruby_api_version ||= RbConfig::CONFIG['ruby_version'].dup
  end


  def self.latest_spec_for name
    dependency   = Gem::Dependency.new name
    fetcher      = Gem::SpecFetcher.fetcher
    spec_tuples, = fetcher.spec_for_dependency dependency

    spec, = spec_tuples.first

    spec
  end


  def self.latest_rubygems_version
    latest_version_for('rubygems-update') or
      raise "Can't find 'rubygems-update' in any repo. Check `gem source list`."
  end


  def self.latest_version_for name
    spec = latest_spec_for name
    spec and spec.version
  end


  def self.ruby_version
    return @ruby_version if defined? @ruby_version
    version = RUBY_VERSION.dup

    if defined?(RUBY_PATCHLEVEL) && RUBY_PATCHLEVEL != -1 then
      version << ".#{RUBY_PATCHLEVEL}"
    elsif defined?(RUBY_REVISION) then
      version << ".dev.#{RUBY_REVISION}"
    end

    @ruby_version = Gem::Version.new version
  end


  def self.rubygems_version
    return @rubygems_version if defined? @rubygems_version
    @rubygems_version = Gem::Version.new Gem::VERSION
  end


  def self.sources
    @sources ||= Gem::SourceList.from(default_sources)
  end


  def self.sources= new_sources
    if !new_sources
      @sources = nil
    else
      @sources = Gem::SourceList.from(new_sources)
    end
  end


  def self.suffix_pattern
    @suffix_pattern ||= "{#{suffixes.join(',')}}"
  end


  def self.suffixes
    @suffixes ||= ['',
                   '.rb',
                   *%w(DLEXT DLEXT2).map { |key|
                     val = RbConfig::CONFIG[key]
                     next unless val and not val.empty?
                     ".#{val}"
                   }
                  ].compact.uniq
  end


  def self.time(msg, width = 0, display = Gem.configuration.verbose)
    now = Time.now

    value = yield

    elapsed = Time.now - now

    ui.say "%2$*1$s: %3$3.3fs" % [-width, msg, elapsed] if display

    value
  end


  def self.ui
    require 'rubygems/user_interaction'

    Gem::DefaultUserInteraction.ui
  end


  def self.use_paths(home, *paths)
    paths = nil if paths == [nil]
    paths = paths.first if Array === Array(paths).first
    self.paths = { "GEM_HOME" => home, "GEM_PATH" => paths }
  end


  def self.user_home
    @user_home ||= find_home.untaint
  end


  def self.win_platform?
    if @@win_platform.nil? then
      ruby_platform = RbConfig::CONFIG['host_os']
      @@win_platform = !!WIN_PATTERNS.find { |r| ruby_platform =~ r }
    end

    @@win_platform
  end


  def self.load_plugin_files plugins # :nodoc:
    plugins.each do |plugin|


      next if plugin =~ /gemcutter-0\.[0-3]/

      begin
        load plugin
      rescue ::Exception => e
        details = "#{plugin.inspect}: #{e.message} (#{e.class})"
        warn "Error loading RubyGems plugin #{details}"
      end
    end
  end


  def self.load_plugins
    if ENV['RUBYGEMS_LOAD_ALL_PLUGINS']
      load_plugin_files find_files('rubygems_plugin', false)
    else
      load_plugin_files find_latest_files('rubygems_plugin', false)
    end
  end


  def self.load_env_plugins
    path = "rubygems_plugin"

    files = []
    $LOAD_PATH.each do |load_path|
      globbed = Dir["#{File.expand_path path, load_path}#{Gem.suffix_pattern}"]

      globbed.each do |load_path_file|
        files << load_path_file if File.file?(load_path_file.untaint)
      end
    end

    load_plugin_files files
  end


  def self.use_gemdeps path = nil
    raise_exception = path

    path ||= ENV['RUBYGEMS_GEMDEPS']
    return unless path

    path = path.dup

    if path == "-" then
      require 'rubygems/util'

      Gem::Util.traverse_parents Dir.pwd do |directory|
        dep_file = GEM_DEP_FILES.find { |f| File.file?(f) }

        next unless dep_file

        path = File.join directory, dep_file
        break
      end
    end

    path.untaint

    unless File.file? path then
      return unless raise_exception

      raise ArgumentError, "Unable to find gem dependencies file at #{path}"
    end

    rs = Gem::RequestSet.new
    rs.load_gemdeps path

    rs.resolve_current.map do |s|
      sp = s.full_spec
      sp.activate
      sp
    end
  rescue Gem::LoadError, Gem::UnsatisfiableDependencyError => e
    warn e.message
    warn "You may need to `gem install -g` to install missing gems"
    warn ""
  end

  class << self

    alias detect_gemdeps use_gemdeps # :nodoc:
  end

  class << self


    attr_reader :loaded_specs


    def register_default_spec(spec)
      new_format = Gem.default_gems_use_full_paths? || spec.require_paths.any? {|path| spec.files.any? {|f| f.start_with? path } }

      if new_format
        prefix_group = spec.require_paths.map {|f| f + "/"}.join("|")
        prefix_pattern = /^(#{prefix_group})/
      end

      spec.files.each do |file|
        if new_format
          file = file.sub(prefix_pattern, "")
          next unless $~
        end

        @path_to_default_spec_map[file] = spec
      end
    end


    def find_unresolved_default_spec(path)
      Gem.suffixes.each do |suffix|
        spec = @path_to_default_spec_map["#{path}#{suffix}"]
        return spec if spec
      end
      nil
    end


    def remove_unresolved_default_spec(spec)
      spec.files.each do |file|
        @path_to_default_spec_map.delete(file)
      end
    end


    def clear_default_specs
      @path_to_default_spec_map.clear
    end


    attr_reader :post_build_hooks


    attr_reader :post_install_hooks


    attr_reader :done_installing_hooks


    attr_reader :post_reset_hooks


    attr_reader :post_uninstall_hooks


    attr_reader :pre_install_hooks


    attr_reader :pre_reset_hooks


    attr_reader :pre_uninstall_hooks
  end


  MARSHAL_SPEC_DIR = "quick/Marshal.#{Gem.marshal_version}/"

  autoload :ConfigFile,         'rubygems/config_file'
  autoload :Dependency,         'rubygems/dependency'
  autoload :DependencyList,     'rubygems/dependency_list'
  autoload :DependencyResolver, 'rubygems/resolver'
  autoload :Installer,          'rubygems/installer'
  autoload :PathSupport,        'rubygems/path_support'
  autoload :Platform,           'rubygems/platform'
  autoload :RequestSet,         'rubygems/request_set'
  autoload :Requirement,        'rubygems/requirement'
  autoload :Resolver,           'rubygems/resolver'
  autoload :Source,             'rubygems/source'
  autoload :SourceList,         'rubygems/source_list'
  autoload :SpecFetcher,        'rubygems/spec_fetcher'
  autoload :Specification,      'rubygems/specification'
  autoload :Version,            'rubygems/version'

  require "rubygems/specification"
end

require 'rubygems/exceptions'

gem_preluded = Gem::GEM_PRELUDE_SUCKAGE and defined? Gem
unless gem_preluded then # TODO: remove guard after 1.9.2 dropped
  begin

    require 'rubygems/defaults/operating_system'
  rescue LoadError
  end

  if defined?(RUBY_ENGINE) then
    begin

      require "rubygems/defaults/#{RUBY_ENGINE}"
    rescue LoadError
    end
  end
end

Gem::Specification.load_defaults

require 'rubygems/core_ext/kernel_gem'
require 'rubygems/core_ext/kernel_require'

Gem.use_gemdeps

