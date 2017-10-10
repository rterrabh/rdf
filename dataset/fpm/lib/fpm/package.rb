require "fpm/namespace" # local
require "fpm/util" # local
require "pathname" # stdlib
require "find"
require "tmpdir" # stdlib
require "backports" # gem 'backports'
require "socket" # stdlib, for Socket.gethostname
require "shellwords" # stdlib, for Shellwords.escape
require "erb" # stdlib, for template processing
require "cabin" # gem "cabin"

class FPM::Package
  include FPM::Util
  include Cabin::Inspectable

  class InvalidArgument < StandardError; end

  class FileAlreadyExists < StandardError
    def to_s
      return "File already exists, refusing to continue: #{super}"
    end # def to_s
  end # class FileAlreadyExists

  class ParentDirectoryMissing < StandardError
    def to_s
      return "Parent directory does not exist: #{File.dirname(super)} - cannot write to #{super}"
    end # def to_s
  end # class ParentDirectoryMissing

  attr_accessor :name

  attr_accessor :version

  attr_accessor :epoch

  attr_accessor :iteration

  attr_accessor :maintainer

  attr_accessor :vendor

  attr_accessor :url

  attr_accessor :category

  attr_accessor :license

  attr_accessor :architecture

  attr_accessor :dependencies

  attr_accessor :provides

  attr_accessor :conflicts

  attr_accessor :replaces

  attr_accessor :description

  attr_accessor :scripts

  attr_accessor :config_files

  attr_accessor :directories

  attr_accessor :attributes

  attr_accessor :attrs

  private

  def initialize
    @attributes = {}

    if ENV.include?("DEBEMAIL") and ENV.include?("DEBFULLNAME")
      @maintainer = "#{ENV["DEBFULLNAME"]} <#{ENV["DEBEMAIL"]}>"
    else
      @maintainer = "<#{ENV["USER"]}@#{Socket.gethostname}>"
    end

    self.class.default_attributes do |attribute, value|
      attributes[attribute] = value
    end

    @name = nil
    @architecture = "native"
    @description = "no description given"
    @version = nil
    @epoch = nil
    @iteration = nil
    @url = nil
    @category = "default"
    @license = "unknown"
    @vendor = "none"

    if self.class.respond_to?(:declared_options)
      self.class.declared_options.each do |option|
        with(option.attribute_name) do |attr|
          attr = "#{attr}?" if !respond_to?(attr)
          #nodyna <send-2793> <not yet classified>
          input.attributes[attr.to_sym] = send(attr) if respond_to?(attr)
        end
      end
    end

    @provides = []
    @conflicts = []
    @replaces = []
    @dependencies = []
    @scripts = {}
    @config_files = []
    @directories = []
    @attrs = {}

    staging_path
    build_path
  end # def initialize

  def type
    self.class.type
  end # def type

  def convert(klass)
    logger.info("Converting #{self.type} to #{klass.type}")

    exclude

    pkg = klass.new
    pkg.cleanup_staging # purge any directories that may have been created by klass.new

    ivars = [
      :@architecture, :@category, :@config_files, :@conflicts,
      :@dependencies, :@description, :@epoch, :@iteration, :@license, :@maintainer,
      :@name, :@provides, :@replaces, :@scripts, :@url, :@vendor, :@version,
      :@directories, :@staging_path, :@attrs
    ]
    ivars.each do |ivar|
      #nodyna <instance_variable_get-2794> <not yet classified>
      #nodyna <instance_variable_set-2795> <not yet classified>
      pkg.instance_variable_set(ivar, instance_variable_get(ivar))
    end

    pkg.attributes.merge!(self.attributes)

    pkg.converted_from(self.class)
    return pkg
  end # def convert

  def converted_from(origin)
  end # def converted

  def input(thing_to_input)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "reading #{self.type} packages")
  end # def input

  def output(path)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "creating #{self.type} packages")
  end # def output

  def staging_path(path=nil)
    @staging_path ||= ::Dir.mktmpdir("package-#{type}-staging") #, ::Dir.pwd)

    if path.nil?
      return @staging_path
    else
      return File.join(@staging_path, path)
    end
  end # def staging_path

  def build_path(path=nil)
    @build_path ||= ::Dir.mktmpdir("package-#{type}-build") #, ::Dir.pwd)

    if path.nil?
      return @build_path
    else
      return File.join(@build_path, path)
    end
  end # def build_path

  def cleanup
    cleanup_staging
    cleanup_build
  end # def cleanup

  def cleanup_staging
    if File.directory?(staging_path)
      logger.debug("Cleaning up staging path", :path => staging_path)
      FileUtils.rm_r(staging_path)
    end
  end # def cleanup_staging

  def cleanup_build
    if File.directory?(build_path)
      logger.debug("Cleaning up build path", :path => build_path)
      FileUtils.rm_r(build_path)
    end
  end # def cleanup_build

  def files
    is_leaf = lambda do |path|
      return true if !(File.directory?(path) and !File.symlink?(path))
      return true if ::Dir.entries(path).sort == [".", ".."]
      return false
    end # is_leaf

    return Enumerator.new { |y| Find.find(staging_path) { |path| y << path } } \
      .select { |path| path != staging_path } \
      .select { |path| is_leaf.call(path) } \
      .collect { |path| path[staging_path.length + 1.. -1] }
  end # def files

  def template_dir
    File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates"))
  end

  def template(path)
    template_path = File.join(template_dir, path)
    template_code = File.read(template_path)
    logger.info("Reading template", :path => template_path)
    erb = ERB.new(template_code, nil, "-")
    erb.filename = template_path
    return erb
  end # def template

  def to_s(fmt="NAME.TYPE")
    fmt = "NAME.TYPE" if fmt.nil?
    fullversion = version.to_s
    fullversion += "-#{iteration}" if iteration
    return fmt.gsub("ARCH", architecture.to_s) \
      .gsub("NAME", name.to_s) \
      .gsub("FULLVERSION", fullversion) \
      .gsub("VERSION", version.to_s) \
      .gsub("ITERATION", iteration.to_s) \
      .gsub("EPOCH", epoch.to_s) \
      .gsub("TYPE", type.to_s)
  end # def to_s

  def edit_file(path)
    editor = ENV['FPM_EDITOR'] || ENV['EDITOR'] || 'vi'
    logger.info("Launching editor", :file => path)
    command = "#{editor} #{Shellwords.escape(path)}"
    system("#{editor} #{Shellwords.escape(path)}")
    if !$?.success?
      raise ProcessFailed.new("'#{editor}' failed (exit code " \
                              "#{$?.exitstatus}) Full command was: "\
                              "#{command}");
    end

    if File.size(path) == 0
      raise "Empty file after editing: #{path.inspect}"
    end
  end # def edit_file

  def exclude
    return if attributes[:excludes].nil?

    if @attributes.include?(:prefix)
      installdir = staging_path(@attributes[:prefix])
    else
      installdir = staging_path
    end

    Find.find(installdir) do |path|
      match_path = path.sub("#{installdir.chomp('/')}/", '')

      attributes[:excludes].each do |wildcard|
        logger.debug("Checking path against wildcard", :path => match_path, :wildcard => wildcard)

        if File.fnmatch(wildcard, match_path)
          logger.info("Removing excluded path", :path => match_path, :matches => wildcard)
          FileUtils.remove_entry_secure(path)
          Find.prune
          break
        end
      end
    end
  end # def exclude


  class << self
    def inherited(klass)
      @subclasses ||= {}
      @subclasses[klass.name.gsub(/.*:/, "").downcase] = klass
    end # def self.inherited

    def types
      return @subclasses
    end # def self.types

    def option(flag, param, help, options={}, &block)
      @options ||= []
      if !flag.is_a?(Array)
        flag = [flag]
      end

      if param == :flag
        flag = flag.collect { |f| "--[no-]#{type}-#{f.gsub(/^--/, "")}" }
      else
        flag = flag.collect { |f| "--#{type}-#{f.gsub(/^--/, "")}" }
      end

      help = "(#{type} only) #{help}"
      @options << [flag, param, help, options, block]
    end # def options

    def apply_options(clampcommand)
      @options ||= []
      @options.each do |args|
        flag, param, help, options, block = args
        clampcommand.option(flag, param, help, options, &block)
      end
    end # def apply_options

    def default_attributes(&block)
      return if @options.nil?
      @options.each do |flag, param, help, options, _block|
        attr = flag.first.gsub(/^-+/, "").gsub(/-/, "_").gsub("[no_]", "")
        attr += "?" if param == :flag
        yield attr.to_sym, options[:default]
      end
    end # def default_attributes

    def type
      self.name.split(':').last.downcase
    end # def self.type
  end # class << self

  def version
    if instance_variable_defined?(:@version) && !@version.nil?
      return @version
    elsif attributes[:version_given?]
      return attributes.fetch(:version)
    end

    return nil
  end # def version

  def script?(name)
    return scripts.include?(name)
  end # def script?

  def script(script_name)
    if attributes[:template_scripts?]
      erb = ERB.new(scripts[script_name], nil, "-")
      erb.filename = "script(#{script_name})"
      return erb.result(binding)
    else
      return scripts[script_name]
    end
  end # def script

  def output_check(output_path)
    if !File.directory?(File.dirname(output_path))
      raise ParentDirectoryMissing.new(output_path)
    end
    if File.file?(output_path)
      if attributes[:force?]
        logger.warn("Force flag given. Overwriting package at #{output_path}")
        File.delete(output_path)
      else
        raise FileAlreadyExists.new(output_path)
      end
    end
  end # def output_path

  def provides=(value)
    if !value.is_a?(Array)
      @provides = [value]
    else
      @provides = value
    end
  end

  public(:type, :initialize, :convert, :input, :output, :to_s, :cleanup, :files,
         :version, :script, :provides=)

  public(:cleanup_staging, :cleanup_build, :staging_path, :converted_from,
         :edit_file, :build_path)
end # class FPM::Package
