require "formula_support"
require "formula_lock"
require "formula_pin"
require "hardware"
require "bottles"
require "build_environment"
require "build_options"
require "formulary"
require "software_spec"
require "install_renamed"
require "pkg_version"
require "tap"
require "formula_renames"
require "keg"

class Formula
  include FileUtils
  include Utils::Inreplace
  extend Enumerable


  attr_reader :name

  attr_reader :full_name

  attr_reader :path


  attr_reader :stable

  attr_reader :devel

  attr_reader :head

  attr_reader :active_spec
  protected :active_spec

  attr_reader :active_spec_sym

  attr_reader :revision

  attr_reader :buildpath

  attr_reader :testpath

  attr_accessor :local_bottle_path

  attr_accessor :build

  def initialize(name, path, spec)
    @name = name
    @path = path
    @revision = self.class.revision || 0

    if path.to_s =~ HOMEBREW_TAP_PATH_REGEX
      @full_name = "#{$1}/#{$2.gsub(/^homebrew-/, "")}/#{name}"
    else
      @full_name = name
    end

    set_spec :stable
    set_spec :devel
    set_spec :head

    @active_spec = determine_active_spec(spec)
    @active_spec_sym = if head?
      :head
    elsif devel?
      :devel
    else
      :stable
    end
    validate_attributes!
    @build = active_spec.build
    @pin = FormulaPin.new(self)
  end

  def set_active_spec(spec_sym)
    #nodyna <send-648> <SD COMPLEX (change-prone variables)>
    spec = send(spec_sym)
    raise FormulaSpecificationError, "#{spec_sym} spec is not available for #{full_name}" unless spec
    @active_spec = spec
    @active_spec_sym = spec_sym
    validate_attributes!
    @build = active_spec.build
  end

  private

  def set_spec(name)
    #nodyna <send-649> <SD MODERATE (change-prone variables)>
    spec = self.class.send(name)
    if spec.url
      spec.owner = self
      #nodyna <instance_variable_set-650> <IVS MODERATE (change-prone variable)>
      instance_variable_set("@#{name}", spec)
    end
  end

  def determine_active_spec(requested)
    #nodyna <send-651> <SD COMPLEX (change-prone variables)>
    spec = send(requested) || stable || devel || head
    spec || raise(FormulaSpecificationError, "formulae require at least a URL")
  end

  def validate_attributes!
    if name.nil? || name.empty? || name =~ /\s/
      raise FormulaValidationError.new(:name, name)
    end

    url = active_spec.url
    if url.nil? || url.empty? || url =~ /\s/
      raise FormulaValidationError.new(:url, url)
    end

    val = version.respond_to?(:to_str) ? version.to_str : version
    if val.nil? || val.empty? || val =~ /\s/
      raise FormulaValidationError.new(:version, val)
    end
  end

  public

  def stable?
    active_spec == stable
  end

  def devel?
    active_spec == devel
  end

  def head?
    active_spec == head
  end

  def bottled?
    active_spec.bottled?
  end

  def bottle_specification
    active_spec.bottle_specification
  end

  def bottle
    Bottle.new(self, bottle_specification) if bottled?
  end

  def desc
    self.class.desc
  end

  def homepage
    self.class.homepage
  end

  def version
    active_spec.version
  end

  def pkg_version
    PkgVersion.new(version, revision)
  end

  def resource(name)
    active_spec.resource(name)
  end

  def oldname
    @oldname ||= if core_formula?
      if FORMULA_RENAMES && FORMULA_RENAMES.value?(name)
        FORMULA_RENAMES.to_a.rassoc(name).first
      end
    elsif tap?
      user, repo = tap.split("/")
      formula_renames = Tap.new(user, repo.sub("homebrew-", "")).formula_renames
      if formula_renames.value?(name)
        formula_renames.to_a.rassoc(name).first
      end
    end
  end

  def resources
    active_spec.resources.values
  end

  def deps
    active_spec.deps
  end

  def requirements
    active_spec.requirements
  end

  def cached_download
    active_spec.cached_download
  end

  def clear_cache
    active_spec.clear_cache
  end

  def patchlist
    active_spec.patches
  end

  def options
    active_spec.options
  end

  def deprecated_options
    active_spec.deprecated_options
  end

  def deprecated_flags
    active_spec.deprecated_flags
  end

  def option_defined?(name)
    active_spec.option_defined?(name)
  end

  def compiler_failures
    active_spec.compiler_failures
  end

  def installed?
    (dir = installed_prefix).directory? && dir.children.length > 0
  end

  def any_version_installed?
    require "tab"
    rack.directory? && rack.subdirs.any? { |keg| (keg/Tab::FILENAME).file? }
  end

  def linked_keg
    Pathname.new("#{HOMEBREW_LIBRARY}/LinkedKegs/#{name}")
  end

  def installed_prefix
    if head && (head_prefix = prefix(PkgVersion.new(head.version, revision))).directory?
      head_prefix
    elsif devel && (devel_prefix = prefix(PkgVersion.new(devel.version, revision))).directory?
      devel_prefix
    elsif stable && (stable_prefix = prefix(PkgVersion.new(stable.version, revision))).directory?
      stable_prefix
    else
      prefix
    end
  end

  def installed_version
    Keg.new(installed_prefix).version
  end

  def prefix(v = pkg_version)
    Pathname.new("#{HOMEBREW_CELLAR}/#{name}/#{v}")
  end

  def rack
    prefix.parent
  end

  def bin
    prefix+"bin"
  end

  def doc
    share+"doc"+name
  end

  def include
    prefix+"include"
  end

  def info
    share+"info"
  end

  def lib
    prefix+"lib"
  end

  def libexec
    prefix+"libexec"
  end

  def man
    share+"man"
  end

  def man1
    man+"man1"
  end

  def man2
    man+"man2"
  end

  def man3
    man+"man3"
  end

  def man4
    man+"man4"
  end

  def man5
    man+"man5"
  end

  def man6
    man+"man6"
  end

  def man7
    man+"man7"
  end

  def man8
    man+"man8"
  end

  def sbin
    prefix+"sbin"
  end

  def share
    prefix+"share"
  end

  def pkgshare
    prefix+"share"+name
  end

  def frameworks
    prefix+"Frameworks"
  end

  def kext_prefix
    prefix+"Library/Extensions"
  end

  def etc
    (HOMEBREW_PREFIX+"etc").extend(InstallRenamed)
  end

  def var
    HOMEBREW_PREFIX+"var"
  end

  def bash_completion
    prefix+"etc/bash_completion.d"
  end

  def zsh_completion
    share+"zsh/site-functions"
  end

  def fish_completion
    share+"fish/vendor_completions.d"
  end

  def bottle_prefix
    prefix+".bottle"
  end

  def logs
    HOMEBREW_LOGS+name
  end

  def plist
    nil
  end
  alias_method :startup_plist, :plist

  def plist_name
    "homebrew.mxcl."+name
  end

  def plist_path
    prefix+(plist_name+".plist")
  end

  def plist_manual
    self.class.plist_manual
  end

  def plist_startup
    self.class.plist_startup
  end

  def opt_prefix
    Pathname.new("#{HOMEBREW_PREFIX}/opt/#{name}")
  end

  def opt_bin
    opt_prefix+"bin"
  end

  def opt_include
    opt_prefix+"include"
  end

  def opt_lib
    opt_prefix+"lib"
  end

  def opt_libexec
    opt_prefix+"libexec"
  end

  def opt_sbin
    opt_prefix+"sbin"
  end

  def opt_share
    opt_prefix+"share"
  end

  def opt_pkgshare
    opt_prefix+"share"+name
  end

  def opt_frameworks
    opt_prefix+"Frameworks"
  end

  def pour_bottle?
    true
  end

  def post_install; end

  def post_install_defined?
    method(:post_install).owner == self.class
  end

  def run_post_install
    build, self.build = self.build, Tab.for_formula(self)
    post_install
  ensure
    self.build = build
  end

  def caveats
    nil
  end

  def keg_only?
    keg_only_reason && keg_only_reason.valid?
  end

  def keg_only_reason
    self.class.keg_only_reason
  end

  def skip_clean?(path)
    return true if path.extname == ".la" && self.class.skip_clean_paths.include?(:la)
    to_check = path.relative_path_from(prefix).to_s
    self.class.skip_clean_paths.include? to_check
  end

  def link_overwrite?(path)
    return false unless path.stat.uid == File.stat(HOMEBREW_BREW_FILE).uid
    begin
      Keg.for(path)
    rescue NotAKegError, Errno::ENOENT
    else
      return false
    end
    to_check = path.relative_path_from(HOMEBREW_PREFIX).to_s
    self.class.link_overwrite_paths.any? do |p|
      p == to_check ||
        to_check.start_with?(p.chomp("/") + "/") ||
        /^#{Regexp.escape(p).gsub('\*', ".*?")}$/ === to_check
    end
  end

  def skip_cxxstdlib_check?
    false
  end

  def require_universal_deps?
    false
  end

  def patch
    unless patchlist.empty?
      ohai "Patching"
      patchlist.each(&:apply)
    end
  end

  def brew
    stage do
      prepare_patches

      begin
        yield self
      ensure
        cp Dir["config.log", "CMakeCache.txt"], logs
      end
    end
  end

  def lock
    @lock = FormulaLock.new(name)
    @lock.lock
    if oldname && (oldname_rack = HOMEBREW_CELLAR/oldname).exist? && oldname_rack.resolved_path == rack
      @oldname_lock = FormulaLock.new(oldname)
      @oldname_lock.lock
    end
  end

  def unlock
    @lock.unlock unless @lock.nil?
    @oldname_lock.unlock unless @oldname_lock.nil?
  end

  def pinnable?
    @pin.pinnable?
  end

  def pinned?
    @pin.pinned?
  end

  def pin
    @pin.pin
  end

  def unpin
    @pin.unpin
  end

  def ==(other)
    instance_of?(other.class) &&
      name == other.name &&
      active_spec == other.active_spec
  end
  alias_method :eql?, :==

  def hash
    name.hash
  end

  def <=>(other)
    return unless Formula === other
    name <=> other.name
  end

  def to_s
    name
  end

  def inspect
    "#<Formula #{name} (#{active_spec_sym}) #{path}>"
  end

  def file_modified?
    return false unless Utils.git_available?

    path.parent.cd do
      diff = Utils.popen_read("git", "diff", "origin/master", "--", "#{path}")
      !diff.empty? && $?.exitstatus == 0
    end
  end

  def std_cmake_args
    %W[
      -DCMAKE_C_FLAGS_RELEASE=
      -DCMAKE_CXX_FLAGS_RELEASE=
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -Wno-dev
    ]
  end

  def self.core_names
    @core_names ||= Dir["#{HOMEBREW_LIBRARY}/Formula/*.rb"].map { |f| File.basename f, ".rb" }.sort
  end

  def self.core_files
    @core_files ||= Pathname.glob("#{HOMEBREW_LIBRARY}/Formula/*.rb")
  end

  def self.tap_names
    @tap_names ||= Tap.flat_map(&:formula_names).sort
  end

  def self.tap_files
    @tap_files ||= Tap.flat_map(&:formula_files)
  end

  def self.names
    @names ||= (core_names + tap_names.map { |name| name.split("/")[-1] }).sort.uniq
  end

  def self.files
    @files ||= core_files + tap_files
  end

  def self.full_names
    @full_names ||= core_names + tap_names
  end

  def self.each
    files.each do |file|
      begin
        yield Formulary.factory(file)
      rescue StandardError => e
        onoe "Failed to import: #{file}"
        puts e
        next
      end
    end
  end

  def self.racks
    @racks ||= if HOMEBREW_CELLAR.directory?
      HOMEBREW_CELLAR.subdirs.reject(&:symlink?)
    else
      []
    end
  end

  def self.installed
    @installed ||= racks.map do |rack|
      begin
        Formulary.from_rack(rack)
      rescue FormulaUnavailableError, TapFormulaAmbiguityError
      end
    end.compact
  end

  def self.aliases
    Dir["#{HOMEBREW_LIBRARY}/Aliases/*"].map { |f| File.basename f }.sort
  end

  def self.[](name)
    Formulary.factory(name)
  end

  def tap?
    HOMEBREW_TAP_DIR_REGEX === path
  end

  def tap
    if path.to_s =~ HOMEBREW_TAP_DIR_REGEX
      "#{$1}/#{$2}"
    elsif core_formula?
      "Homebrew/homebrew"
    end
  end

  def print_tap_action(options = {})
    if tap?
      verb = options[:verb] || "Installing"
      ohai "#{verb} #{name} from #{tap}"
    end
  end

  def core_formula?
    path == Formulary.core_path(name)
  end

  def env
    self.class.env
  end

  def conflicts
    self.class.conflicts
  end

  def recursive_dependencies(&block)
    Dependency.expand(self, &block)
  end

  def recursive_requirements(&block)
    Requirement.expand(self, &block)
  end

  def to_hash
    hsh = {
      "name" => name,
      "full_name" => full_name,
      "desc" => desc,
      "homepage" => homepage,
      "oldname" => oldname,
      "versions" => {
        "stable" => (stable.version.to_s if stable),
        "bottle" => bottle ? true : false,
        "devel" => (devel.version.to_s if devel),
        "head" => (head.version.to_s if head)
      },
      "revision" => revision,
      "installed" => [],
      "linked_keg" => (linked_keg.resolved_path.basename.to_s if linked_keg.exist?),
      "keg_only" => keg_only?,
      "dependencies" => deps.map(&:name).uniq,
      "conflicts_with" => conflicts.map(&:name),
      "caveats" => caveats
    }

    hsh["requirements"] = requirements.map do |req|
      {
        "name" => req.name,
        "default_formula" => req.default_formula,
        "cask" => req.cask,
        "download" => req.download
      }
    end

    hsh["options"] = options.map do |opt|
      { "option" => opt.flag, "description" => opt.description }
    end

    if rack.directory?
      rack.subdirs.each do |keg_path|
        keg = Keg.new keg_path
        tab = Tab.for_keg keg_path

        hsh["installed"] << {
          "version" => keg.version.to_s,
          "used_options" => tab.used_options.as_flags,
          "built_as_bottle" => tab.built_bottle,
          "poured_from_bottle" => tab.poured_from_bottle
        }
      end

      hsh["installed"] = hsh["installed"].sort_by { |i| Version.new(i["version"]) }
    end

    hsh
  end

  def fetch
    active_spec.fetch
  end

  def verify_download_integrity(fn)
    active_spec.verify_download_integrity(fn)
  end

  def run_test
    old_home = ENV["HOME"]
    build, self.build = self.build, Tab.for_formula(self)
    mktemp do
      @testpath = Pathname.pwd
      ENV["HOME"] = @testpath
      setup_test_home @testpath
      test
    end
  ensure
    @testpath = nil
    self.build = build
    ENV["HOME"] = old_home
  end

  def test_defined?
    false
  end

  def test
  end

  def test_fixtures(file)
    HOMEBREW_LIBRARY.join("Homebrew", "test", "fixtures", file)
  end

  def install
  end

  protected

  def setup_test_home(home)
    user_site_packages = home/"Library/Python/2.7/lib/python/site-packages"
    user_site_packages.mkpath
    (user_site_packages/"homebrew.pth").write <<-EOS.undent
      import site; site.addsitedir("#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
      import sys; sys.path.insert(0, "#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
    EOS
  end

  public

  def system(cmd, *args)
    verbose = ARGV.verbose?
    pretty_args = args.dup
    if cmd == "./configure" && !verbose
      pretty_args.delete "--disable-dependency-tracking"
      pretty_args.delete "--disable-debug"
    end
    pretty_args.each_index do |i|
      if pretty_args[i].to_s.start_with? "import setuptools"
        pretty_args[i] = "import setuptools..."
      end
    end
    ohai "#{cmd} #{pretty_args*" "}".strip

    @exec_count ||= 0
    @exec_count += 1
    logfn = "#{logs}/%02d.%s" % [@exec_count, File.basename(cmd).split(" ").first]
    logs.mkpath

    File.open(logfn, "w") do |log|
      log.puts Time.now, "", cmd, args, ""
      log.flush

      if verbose
        rd, wr = IO.pipe
        begin
          pid = fork do
            rd.close
            log.close
            exec_cmd(cmd, args, wr, logfn)
          end
          wr.close

          while buf = rd.gets
            log.puts buf
            puts buf
          end
        ensure
          rd.close
        end
      else
        pid = fork { exec_cmd(cmd, args, log, logfn) }
      end

      Process.wait(pid)

      $stdout.flush

      unless $?.success?
        log.flush
        Kernel.system "/usr/bin/tail", "-n", "5", logfn unless verbose
        log.puts

        require "cmd/config"
        require "cmd/--env"

        env = ENV.to_hash

        Homebrew.dump_verbose_config(log)
        log.puts
        Homebrew.dump_build_env(env, log)

        raise BuildError.new(self, cmd, args, env)
      end
    end
  end

  private

  def exec_cmd(cmd, args, out, logfn)
    ENV["HOMEBREW_CC_LOG_PATH"] = logfn

    if cmd.to_s.start_with? "xcodebuild"
      ENV.remove_cc_etc
    end

    if cmd == "python"
      setup_py_in_args = %w[setup.py build.py].include?(args.first)
      setuptools_shim_in_args = args.any? { |a| a.to_s.start_with? "import setuptools" }
      if setup_py_in_args || setuptools_shim_in_args
        ENV.refurbish_args
      end
    end

    $stdout.reopen(out)
    $stderr.reopen(out)
    out.close
    args.collect!(&:to_s)
    exec(cmd, *args) rescue nil
    puts "Failed to execute: #{cmd}"
    exit! 1 # never gets here unless exec threw or failed
  end

  def stage
    active_spec.stage do
      @buildpath = Pathname.pwd
      env_home = buildpath/".brew_home"
      mkdir_p env_home

      old_home, ENV["HOME"] = ENV["HOME"], env_home

      begin
        yield
      ensure
        @buildpath = nil
        ENV["HOME"] = old_home
      end
    end
  end

  def prepare_patches
    active_spec.add_legacy_patches(patches) if respond_to?(:patches)

    patchlist.grep(DATAPatch) { |p| p.path = path }

    patchlist.each do |patch|
      patch.verify_download_integrity(patch.fetch) if patch.external?
    end
  end

  def self.method_added(method)
    case method
    when :brew
      raise "You cannot override Formula#brew in class #{name}"
    when :test
      #nodyna <define_method-652> <DM MODERATE (events)>
      define_method(:test_defined?) { true }
    when :options
      instance = allocate

      specs.each do |spec|
        instance.options.each do |opt, desc|
          spec.option(opt[/^--(.+)$/, 1], desc)
        end
      end

      remove_method(:options)
    end
  end

  class << self
    include BuildEnvironmentDSL

    attr_reader :keg_only_reason

    attr_rw :desc

    attr_rw :homepage

    attr_reader :plist_startup

    attr_reader :plist_manual

    attr_rw :revision

    def specs
      @specs ||= [stable, devel, head].freeze
    end

    def url(val, specs = {})
      stable.url(val, specs)
    end

    def version(val = nil)
      stable.version(val)
    end

    def mirror(val)
      stable.mirror(val)
    end

    Checksum::TYPES.each do |type|
      #nodyna <send-653> <SD MODERATE (array)>
      #nodyna <define_method-654> <DM MODERATE (array)>
      define_method(type) { |val| stable.send(type, val) }
    end

    def bottle(*, &block)
      stable.bottle(&block)
    end

    def build
      stable.build
    end

    def stable(&block)
      @stable ||= SoftwareSpec.new
      return @stable unless block_given?
      #nodyna <instance_eval-655> <IEV COMPLEX (block execution)>
      @stable.instance_eval(&block)
    end

    def devel(&block)
      @devel ||= SoftwareSpec.new
      return @devel unless block_given?
      #nodyna <instance_eval-656> <IEV COMPLEX (block execution)>
      @devel.instance_eval(&block)
    end

    def head(val = nil, specs = {}, &block)
      @head ||= HeadSoftwareSpec.new
      if block_given?
        #nodyna <instance_eval-657> <IEV COMPLEX (block execution)>
        @head.instance_eval(&block)
      elsif val
        @head.url(val, specs)
      else
        @head
      end
    end

    def resource(name, klass = Resource, &block)
      specs.each do |spec|
        spec.resource(name, klass, &block) unless spec.resource_defined?(name)
      end
    end

    def go_resource(name, &block)
      specs.each { |spec| spec.go_resource(name, &block) }
    end

    def depends_on(dep)
      specs.each { |spec| spec.depends_on(dep) }
    end

    def option(name, description = "")
      specs.each { |spec| spec.option(name, description) }
    end

    def deprecated_option(hash)
      specs.each { |spec| spec.deprecated_option(hash) }
    end

    def patch(strip = :p1, src = nil, &block)
      specs.each { |spec| spec.patch(strip, src, &block) }
    end

    def plist_options(options)
      @plist_startup = options[:startup]
      @plist_manual = options[:manual]
    end

    def conflicts
      @conflicts ||= []
    end

    def conflicts_with(*names)
      opts = Hash === names.last ? names.pop : {}
      names.each { |name| conflicts << FormulaConflict.new(name, opts[:because]) }
    end

    def skip_clean(*paths)
      paths.flatten!
      skip_clean_paths.merge(paths)
    end

    def skip_clean_paths
      @skip_clean_paths ||= Set.new
    end

    def keg_only(reason, explanation = "")
      @keg_only_reason = KegOnlyReason.new(reason, explanation)
    end

    def cxxstdlib_check(check_type)
      #nodyna <define_method-658> <DM MODERATE (events)>
      define_method(:skip_cxxstdlib_check?) { true } if check_type == :skip
    end

    def fails_with(compiler, &block)
      specs.each { |spec| spec.fails_with(compiler, &block) }
    end

    def needs(*standards)
      specs.each { |spec| spec.needs(*standards) }
    end


    def test(&block)
      #nodyna <define_method-659> <DM COMPLEX (events)>
      define_method(:test, &block)
    end

    def link_overwrite(*paths)
      paths.flatten!
      link_overwrite_paths.merge(paths)
    end

    def link_overwrite_paths
      @link_overwrite_paths ||= Set.new
    end
  end
end
