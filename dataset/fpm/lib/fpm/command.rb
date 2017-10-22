require "rubygems"
require "fpm/namespace"
require "fpm/version"
require "fpm/util"
require "clamp"
require "ostruct"
require "fpm"
require "tmpdir" # for Dir.tmpdir

if $DEBUG
  Cabin::Channel.get(Kernel).subscribe($stdout)
  Cabin::Channel.get(Kernel).level = :debug
end

Dir[File.join(File.dirname(__FILE__), "package", "*.rb")].each do |plugin|
  Cabin::Channel.get(Kernel).info("Loading plugin", :path => plugin)

  require "fpm/package/#{File.basename(plugin)}"
end


class FPM::Command < Clamp::Command
  include FPM::Util

  def help(*args)
    lines = [
      "Intro:",
      "",
      "  This is fpm version #{FPM::VERSION}",
      "",
      "  If you think something is wrong, it's probably a bug! :)",
      "  Please file these here: https://github.com/jordansissel/fpm/issues",
      "",
      "  You can find support on irc (#fpm on freenode irc) or via email with",
      "  fpm-users@googlegroups.com",
      "",
      "Loaded package types:",
    ]
    FPM::Package.types.each do |name, _|
      lines.push("  - #{name}")
    end
    lines.push("")
    lines.push(super)
    return lines.join("\n")
  end # def help

  option "-t", "OUTPUT_TYPE",
    "the type of package you want to create (deb, rpm, solaris, etc)",
    :attribute_name => :output_type
  option "-s", "INPUT_TYPE",
    "the package type to use as input (gem, rpm, python, etc)",
    :attribute_name => :input_type
  option "-C", "CHDIR",
    "Change directory to here before searching for files",
    :attribute_name => :chdir
  option "--prefix", "PREFIX",
    "A path to prefix files with when building the target package. This may " \
    "be necessary for all input packages. For example, the 'gem' type will " \
    "prefix with your gem directory automatically."
  option ["-p", "--package"], "OUTPUT", "The package file path to output."
  option ["-f", "--force"], :flag, "Force output even if it will overwrite an " \
    "existing file", :default => false
  option ["-n", "--name"], "NAME", "The name to give to the package"

  loglevels = %w(error warn info debug)
  option "--log", "LEVEL", "Set the log level. Values: #{loglevels.join(", ")}.",
    :attribute_name => :log_level do |val|
    val.downcase.tap do |v|
      if !loglevels.include?(v)
        raise FPM::Package::InvalidArgument, "Invalid log level, #{v.inspect}. Must be one of: #{loglevels.join(", ")}"
      end
    end
  end # --log
  option "--verbose", :flag, "Enable verbose output"
  option "--debug", :flag, "Enable debug output"
  option "--debug-workspace", :flag, "Keep any file workspaces around for " \
    "debugging. This will disable automatic cleanup of package staging and " \
    "build paths. It will also print which directories are available."
  option ["-v", "--version"], "VERSION", "The version to give to the package",
    :default => 1.0
  option "--iteration", "ITERATION",
    "The iteration to give to the package. RPM calls this the 'release'. " \
    "FreeBSD calls it 'PORTREVISION'. Debian calls this 'debian_revision'"
  option "--epoch", "EPOCH",
    "The epoch value for this package. RPM and Debian calls this 'epoch'. " \
    "FreeBSD calls this 'PORTEPOCH'"
  option "--license", "LICENSE",
    "(optional) license name for this package"
  option "--vendor", "VENDOR",
    "(optional) vendor name for this package"
  option "--category", "CATEGORY",
    "(optional) category this package belongs to", :default => "none"
  option ["-d", "--depends"], "DEPENDENCY",
    "A dependency. This flag can be specified multiple times. Value is " \
    "usually in the form of: -d 'name' or -d 'name > version'",
    :multivalued => true, :attribute_name => :dependencies

  option "--no-depends", :flag, "Do not list any dependencies in this package",
    :default => false

  option "--no-auto-depends", :flag, "Do not list any dependencies in this " \
    "package automatically", :default => false

  option "--provides", "PROVIDES",
    "What this package provides (usually a name). This flag can be " \
    "specified multiple times.", :multivalued => true,
    :attribute_name => :provides
  option "--conflicts", "CONFLICTS",
    "Other packages/versions this package conflicts with. This flag can " \
    "specified multiple times.", :multivalued => true,
    :attribute_name => :conflicts
  option "--replaces", "REPLACES",
    "Other packages/versions this package replaces. This flag can be " \
    "specified multiple times.", :multivalued => true,
    :attribute_name => :replaces

  option "--config-files", "CONFIG_FILES",
    "Mark a file in the package as being a config file. This uses 'conffiles'" \
    " in debs and %config in rpm. If you have multiple files to mark as " \
    "configuration files, specify this flag multiple times.  If argument is " \
    "directory all files inside it will be recursively marked as config files.",
    :multivalued => true, :attribute_name => :config_files
  option "--directories", "DIRECTORIES", "Recursively mark a directory as being owned " \
    "by the package", :multivalued => true, :attribute_name => :directories
  option ["-a", "--architecture"], "ARCHITECTURE",
    "The architecture name. Usually matches 'uname -m'. For automatic values," \
    " you can use '-a all' or '-a native'. These two strings will be " \
    "translated into the correct value for your platform and target package type."
  option ["-m", "--maintainer"], "MAINTAINER",
    "The maintainer of this package.",
    :default => "<#{ENV["USER"]}@#{Socket.gethostname}>"
  option ["-S", "--package-name-suffix"], "PACKAGE_NAME_SUFFIX",
    "a name suffix to append to package and dependencies."
  option ["-e", "--edit"], :flag,
    "Edit the package spec before building.", :default => false

  excludes = []
  option ["-x", "--exclude"], "EXCLUDE_PATTERN",
    "Exclude paths matching pattern (shell wildcard globs valid here). " \
    "If you have multiple file patterns to exclude, specify this flag " \
    "multiple times.", :attribute_name => :excludes do |val|
    excludes << val
    next excludes
  end # -x / --exclude

  option "--exclude-file", "EXCLUDE_PATH",
    "The path to a file containing a newline-sparated list of "\
    "patterns to exclude from input."

  option "--description", "DESCRIPTION", "Add a description for this package." \
    " You can include '\n' sequences to indicate newline breaks.",
    :default => "no description" do |val|
    val.gsub("\\n", "\n")
  end
  option "--url", "URI", "Add a url for this package.",
    :default => "http://example.com/no-uri-given"
  option "--inputs", "INPUTS_PATH",
    "The path to a file containing a newline-separated list of " \
    "files and dirs to use as input."

  option "--post-install", "FILE",
    "(DEPRECATED, use --after-install) A script to be run after " \
    "package installation" do |val|
    @after_install = File.expand_path(val) # Get the full path to the script
  end # --post-install (DEPRECATED)
  option "--pre-install", "FILE",
    "(DEPRECATED, use --before-install) A script to be run before " \
    "package installation" do |val|
    @before_install = File.expand_path(val) # Get the full path to the script
  end # --pre-install (DEPRECATED)
  option "--post-uninstall", "FILE",
      "(DEPRECATED, use --after-remove) A script to be run after " \
      "package removal" do |val|
    @after_remove = File.expand_path(val) # Get the full path to the script
  end # --post-uninstall (DEPRECATED)
  option "--pre-uninstall", "FILE",
    "(DEPRECATED, use --before-remove) A script to be run before " \
    "package removal"  do |val|
    @before_remove = File.expand_path(val) # Get the full path to the script
  end # --pre-uninstall (DEPRECATED)

  option "--after-install", "FILE",
    "A script to be run after package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-install
  option "--before-install", "FILE",
    "A script to be run before package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --before-install
  option "--after-remove", "FILE",
    "A script to be run after package removal" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-remove
  option "--before-remove", "FILE",
    "A script to be run before package removal" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --before-remove
  option "--after-upgrade", "FILE",
    "A script to be run after package upgrade. If not specified,\n" \
        "--before-install, --after-install, --before-remove, and \n" \
        "--after-remove will behave in a backwards-compatible manner\n" \
        "(they will not be upgrade-case aware).\n" \
        "Currently only supports deb and rpm packages." do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-upgrade
  option "--before-upgrade", "FILE",
    "A script to be run before package upgrade. If not specified,\n" \
        "--before-install, --after-install, --before-remove, and \n" \
        "--after-remove will behave in a backwards-compatible manner\n" \
        "(they will not be upgrade-case aware).\n" \
        "Currently only supports deb and rpm packages." do |val|
    File.expand_path(val) # Get the full path to the script
  end # --before-upgrade

  option "--template-scripts", :flag,
    "Allow scripts to be templated. This lets you use ERB to template your " \
    "packaging scripts (for --after-install, etc). For example, you can do " \
    "things like <%= name %> to get the package name. For more information, " \
    "see the fpm wiki: " \
    "https://github.com/jordansissel/fpm/wiki/Script-Templates"

  option "--template-value", "KEY=VALUE",
    "Make 'key' available in script templates, so <%= key %> given will be " \
    "the provided value. Implies --template-scripts",
    :multivalued => true do |kv|
    @template_scripts = true
    next kv.split("=", 2)
  end

  option "--workdir", "WORKDIR",
    "The directory you want fpm to do its work in, where 'work' is any file " \
    "copying, downloading, etc. Roughly any scratch space fpm needs to build " \
    "your package.", :default => Dir.tmpdir

  parameter "[ARGS] ...",
    "Inputs to the source package type. For the 'dir' type, this is the files" \
    " and directories you want to include in the package. For others, like " \
    "'gem', it specifies the packages to download and use as the gem input",
    :attribute_name => :args

  FPM::Package.types.each do |name, klass|
    klass.apply_options(self)
  end

  def initialize(*args)
    super(*args)
    @conflicts = []
    @replaces = []
    @provides = []
    @dependencies = []
    @config_files = []
    @directories = []
  end # def initialize

  def execute
    if ARGV == [ "--version" ]
      puts FPM::VERSION
      return 0
    end

    logger.level = :warn
    logger.level = :info if verbose? # --verbose
    logger.level = :debug if debug? # --debug
    if log_level
      logger.level = log_level.to_sym
    end


    if (stray_flags = args.grep(/^-/); stray_flags.any?)
      logger.warn("All flags should be before the first argument " \
                   "(stray flags found: #{stray_flags}")
    end

    if input_type == "dir" and args.empty? and !chdir.nil?
      logger.info("No args, but -s dir and -C are given, assuming '.' as input")
      args << "."
    end

    logger.info("Setting workdir", :workdir => workdir)
    ENV["TMP"] = workdir

    validator = Validator.new(self)
    if !validator.ok?
      validator.messages.each do |message|
        logger.warn(message)
      end

      logger.fatal("Fix the above problems, and you'll be rolling packages in no time!")
      return 1
    end
    input_class = FPM::Package.types[input_type]
    output_class = FPM::Package.types[output_type]

    input = input_class.new

    input.attributes ||= {}

    self.class.declared_options.each do |option|
      with(option.attribute_name) do |attr|
        next if attr == "help"

        flag_given = instance_variable_defined?("@#{attr}")
        input.attributes["#{attr}_given?".to_sym] = flag_given
        attr = "#{attr}?" if !respond_to?(attr) # handle boolean :flag cases
        #nodyna <send-2796> <SD COMPLEX (change-prone variables)>
        input.attributes[attr.to_sym] = send(attr) if respond_to?(attr)
        #nodyna <send-2797> <SD COMPLEX (change-prone variables)>
        logger.debug("Setting attribute", attr.to_sym => send(attr))
      end
    end

    args.each do |arg|
      input.input(arg)
    end

    if !inputs.nil?
      if !File.exists?(inputs)
        logger.fatal("File given for --inputs does not exist (#{inputs})")
        return 1
      end

      File.new(inputs, "r").each_line do |line|
        input.input(line.strip)
      end
    end

    if !exclude_file.nil?
      if !File.exists?(exclude_file)
        logger.fatal("File given for --exclude-file does not exist (#{exclude_file})")
        return 1
      end

      File.new(exclude-file, "r").each_line do |line| 
        excludes << line.strip
      end
    end

    set = proc do |object, attribute|
      #nodyna <send-2798> <SD MODERATE (change-prone variables)>
      #nodyna <send-2799> <SD MODERATE (change-prone variables)>
      #nodyna <send-2800> <SD MODERATE (change-prone variables)>
      if object.send(attribute).nil? || send(attribute) != send("default_#{attribute}")
        logger.info("Setting from flags: #{attribute}=#{send(attribute)}")
        #nodyna <send-2802> <SD MODERATE (change-prone variables)>
        #nodyna <send-2803> <SD MODERATE (change-prone variables)>
        object.send("#{attribute}=", send(attribute))
      end
    end
    set.call(input, :architecture)
    set.call(input, :category)
    set.call(input, :description)
    set.call(input, :epoch)
    set.call(input, :iteration)
    set.call(input, :license)
    set.call(input, :maintainer)
    set.call(input, :name)
    set.call(input, :url)
    set.call(input, :vendor)
    set.call(input, :version)
    set.call(input, :architecture)

    input.conflicts += conflicts
    input.dependencies += dependencies
    input.provides += provides
    input.replaces += replaces
    input.config_files += config_files
    input.directories += directories

    h = {}
    attrs.each do | e |

      s = e.split(':', 2)
      h[s.last] = s.first
    end

    input.attrs = h


    script_errors = []
    setscript = proc do |scriptname|
      #nodyna <send-2804> <SD MODERATE (change-prone variables)>
      path = self.send(scriptname)
      next if path.nil?

      if !File.exists?(path)
        logger.error("No such file (for #{scriptname.to_s}): #{path.inspect}")
        script_errors << path
      end

      input.scripts[scriptname] = File.read(path)
    end

    setscript.call(:before_install)
    setscript.call(:after_install)
    setscript.call(:before_remove)
    setscript.call(:after_remove)
    setscript.call(:before_upgrade)
    setscript.call(:after_upgrade)

    return 1 if script_errors.any?

    if input.name.nil? or input.name.empty?
      logger.fatal("No name given for this package (set name with '-n', " \
                    "for example, '-n packagename')")
      return 1
    end

    output = input.convert(output_class)

    if template_scripts?
      template_value_list.each do |key, value|
        #nodyna <define_method-2805> <DM COMPLEX (array)>
        #nodyna <send-2806> <SD MODERATE (private methods)>
        (class << output; self; end).send(:define_method, key) { value }
      end
    end


    if ! package.nil? && File.directory?(package)
      package_file = File.join(package, output.to_s)
    else
      package_file = output.to_s(package)
    end

    begin
      output.output(package_file)
    rescue FPM::Package::FileAlreadyExists => e
      logger.fatal(e.message)
      return 1
    rescue FPM::Package::ParentDirectoryMissing => e
      logger.fatal(e.message)
      return 1
    end

    logger.log("Created package", :path => package_file)
    return 0
  rescue FPM::Util::ExecutableNotFound => e
    logger.error("Need executable '#{e}' to convert #{input_type} to #{output_type}")
    return 1
  rescue FPM::InvalidPackageConfiguration => e
    logger.error("Invalid package configuration: #{e}")
    return 1
  rescue FPM::Util::ProcessFailed => e
    logger.error("Process failed: #{e}")
    return 1
  ensure
    if debug_workspace?
      [input, output].each do |plugin|
        next if plugin.nil?
        [:staging_path, :build_path].each do |pathtype|
          #nodyna <send-2807> <SD MODERATE (array)>
          path = plugin.send(pathtype)
          next unless Dir.open(path).to_a.size > 2
          logger.log("plugin directory", :plugin => plugin.type, :pathtype => pathtype, :path => path)
        end
      end
    else
      input.cleanup unless input.nil?
      output.cleanup unless output.nil?
    end
  end # def execute

  def run(*args)
    logger.subscribe(STDOUT)

    rc_files = [ ".fpm" ]
    rc_files << File.join(ENV["HOME"], ".fpm") if ENV["HOME"]

    rc_files.each do |rc_file|
      if File.readable? rc_file
        logger.warn("Loading flags from rc file #{rc_file}")
        File.readlines(rc_file).each do |line|
          Shellwords.shellsplit(line).reverse.each do |arg|
            ARGV.unshift(arg)
          end
        end
      end
    end

    super(*args)
  rescue FPM::Package::InvalidArgument => e
    logger.error("Invalid package argument: #{e}")
    return 1
  end # def run

  class Validator
    include FPM::Util
    private

    def initialize(command)
      @command = command
      @valid = true
      @messages = []

      validate
    end # def initialize

    def ok?
      return @valid
    end # def ok?

    def validate
      mandatory(@command.input_type,
                "Missing required -s flag. What package source did you want?")
      mandatory(@command.output_type,
                "Missing required -t flag. What package output did you want?")

      types = FPM::Package.types.keys.sort
      with(@command.input_type) do |val|
        next if val.nil?
        mandatory(FPM::Package.types.include?(val),
                  "Invalid input package -s flag) type #{val.inspect}. " \
                  "Expected one of: #{types.join(", ")}")
      end

      with(@command.output_type) do |val|
        next if val.nil?
        mandatory(FPM::Package.types.include?(val),
                  "Invalid output package (-t flag) type #{val.inspect}. " \
                  "Expected one of: #{types.join(", ")}")
      end

      with (@command.dependencies) do |dependencies|
        dependencies.each do |dep|
          next unless dep.include?(",")
          splitdeps = dep.split(/\s*,\s*/)
          @messages << "Dependencies should not " \
            "include commas. If you want to specify multiple dependencies, use " \
            "the '-d' flag multiple times. Example: " + \
            splitdeps.map { |d| "-d '#{d}'" }.join(" ")
        end
      end

      if @command.inputs
        mandatory(@command.input_type == "dir", "--inputs is only valid with -s dir")
      end

      mandatory(@command.args.any? || @command.inputs || @command.input_type == 'empty',
                "No parameters given. You need to pass additional command " \
                "arguments so that I know what you want to build packages " \
                "from. For example, for '-s dir' you would pass a list of " \
                "files and directories. For '-s gem' you would pass a one" \
                " or more gems to package from. As a full example, this " \
                "will make an rpm of the 'json' rubygem: " \
                "`fpm -s gem -t rpm json`")
    end # def validate

    def mandatory(value, message)
      if value.nil? or !value
        @messages << message
        @valid = false
      end
    end # def mandatory

    def messages
      return @messages
    end # def messages

    public(:initialize, :ok?, :messages)
  end # class Validator
end # class FPM::Program
