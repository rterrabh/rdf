
require 'rubygems/user_interaction'
require 'rbconfig'


class Gem::ConfigFile

  include Gem::UserInteraction

  DEFAULT_BACKTRACE = false
  DEFAULT_BULK_THRESHOLD = 1000
  DEFAULT_VERBOSITY = true
  DEFAULT_UPDATE_SOURCES = true


  OPERATING_SYSTEM_DEFAULTS = {}


  PLATFORM_DEFAULTS = {}


  SYSTEM_CONFIG_PATH =
    begin
      require "etc"
      Etc.sysconfdir
    rescue LoadError, NoMethodError
      begin
        require 'Win32API'

        CSIDL_COMMON_APPDATA = 0x0023
        path = 0.chr * 260
        if RUBY_VERSION > '1.9' then
          SHGetFolderPath = Win32API.new 'shell32', 'SHGetFolderPath', 'PLPLP',
          'L', :stdcall
          SHGetFolderPath.call nil, CSIDL_COMMON_APPDATA, nil, 1, path
        else
          SHGetFolderPath = Win32API.new 'shell32', 'SHGetFolderPath', 'LLLLP',
          'L'
          SHGetFolderPath.call 0, CSIDL_COMMON_APPDATA, 0, 1, path
        end

        path.strip
      rescue LoadError
        RbConfig::CONFIG["sysconfdir"] || "/etc"
      end
    end


  SYSTEM_WIDE_CONFIG_FILE = File.join SYSTEM_CONFIG_PATH, 'gemrc'


  attr_reader :args


  attr_accessor :path


  attr_accessor :home


  attr_writer :backtrace


  attr_accessor :bulk_threshold


  attr_accessor :verbose


  attr_accessor :update_sources


  attr_accessor :disable_default_gem_server


  attr_reader :ssl_verify_mode


  attr_accessor :ssl_ca_cert


  attr_reader :ssl_client_cert


  def initialize(args)
    @config_file_name = nil
    need_config_file_name = false

    arg_list = []

    args.each do |arg|
      if need_config_file_name then
        @config_file_name = arg
        need_config_file_name = false
      elsif arg =~ /^--config-file=(.*)/ then
        @config_file_name = $1
      elsif arg =~ /^--config-file$/ then
        need_config_file_name = true
      else
        arg_list << arg
      end
    end

    @backtrace = DEFAULT_BACKTRACE
    @bulk_threshold = DEFAULT_BULK_THRESHOLD
    @verbose = DEFAULT_VERBOSITY
    @update_sources = DEFAULT_UPDATE_SOURCES

    operating_system_config = Marshal.load Marshal.dump(OPERATING_SYSTEM_DEFAULTS)
    platform_config = Marshal.load Marshal.dump(PLATFORM_DEFAULTS)
    system_config = load_file SYSTEM_WIDE_CONFIG_FILE
    user_config = load_file config_file_name.dup.untaint
    environment_config = (ENV['GEMRC'] || '').split(/[:;]/).inject({}) do |result, file|
      result.merge load_file file
    end


    @hash = operating_system_config.merge platform_config
    @hash = @hash.merge system_config
    @hash = @hash.merge user_config
    @hash = @hash.merge environment_config

    @backtrace                  = @hash[:backtrace]                  if @hash.key? :backtrace
    @bulk_threshold             = @hash[:bulk_threshold]             if @hash.key? :bulk_threshold
    @home                       = @hash[:gemhome]                    if @hash.key? :gemhome
    @path                       = @hash[:gempath]                    if @hash.key? :gempath
    @update_sources             = @hash[:update_sources]             if @hash.key? :update_sources
    @verbose                    = @hash[:verbose]                    if @hash.key? :verbose
    @disable_default_gem_server = @hash[:disable_default_gem_server] if @hash.key? :disable_default_gem_server

    @ssl_verify_mode  = @hash[:ssl_verify_mode]  if @hash.key? :ssl_verify_mode
    @ssl_ca_cert      = @hash[:ssl_ca_cert]      if @hash.key? :ssl_ca_cert
    @ssl_client_cert  = @hash[:ssl_client_cert]  if @hash.key? :ssl_client_cert

    @api_keys         = nil
    @rubygems_api_key = nil

    Gem.sources = @hash[:sources] if @hash.key? :sources
    handle_arguments arg_list
  end


  def api_keys
    load_api_keys unless @api_keys

    @api_keys
  end


  def check_credentials_permissions
    return if Gem.win_platform? # windows doesn't write 0600 as 0600
    return unless File.exist? credentials_path

    existing_permissions = File.stat(credentials_path).mode & 0777

    return if existing_permissions == 0600

    alert_error <<-ERROR
Your gem push credentials file located at:

\t#{credentials_path}

has file permissions of 0#{existing_permissions.to_s 8} but 0600 is required.

To fix this error run:

\tchmod 0600 #{credentials_path}

You should reset your credentials at:

\thttps://rubygems.org/profile/edit

if you believe they were disclosed to a third party.
    ERROR

    terminate_interaction 1
  end


  def credentials_path
    File.join Gem.user_home, '.gem', 'credentials'
  end

  def load_api_keys
    check_credentials_permissions

    @api_keys = if File.exist? credentials_path then
                  load_file(credentials_path)
                else
                  @hash
                end

    if @api_keys.key? :rubygems_api_key then
      @rubygems_api_key    = @api_keys[:rubygems_api_key]
      @api_keys[:rubygems] = @api_keys.delete :rubygems_api_key unless
        @api_keys.key? :rubygems
    end
  end


  def rubygems_api_key
    load_api_keys unless @rubygems_api_key

    @rubygems_api_key
  end


  def rubygems_api_key= api_key
    check_credentials_permissions

    config = load_file(credentials_path).merge(:rubygems_api_key => api_key)

    dirname = File.dirname credentials_path
    Dir.mkdir(dirname) unless File.exist? dirname

    Gem.load_yaml

    permissions = 0600 & (~File.umask)
    File.open(credentials_path, 'w', permissions) do |f|
      f.write config.to_yaml
    end

    @rubygems_api_key = api_key
  end

  YAMLErrors = [ArgumentError]
  YAMLErrors << Psych::SyntaxError if defined?(Psych::SyntaxError)

  def load_file(filename)
    Gem.load_yaml

    return {} unless filename and File.exist? filename

    begin
      content = YAML.load(File.read(filename))
      unless content.kind_of? Hash
        warn "Failed to load #{filename} because it doesn't contain valid YAML hash"
        return {}
      end
      return content
    rescue *YAMLErrors => e
      warn "Failed to load #{filename}, #{e}"
    rescue Errno::EACCES
      warn "Failed to load #{filename} due to permissions problem."
    end

    {}
  end

  def backtrace
    @backtrace or $DEBUG
  end

  def config_file_name
    @config_file_name || Gem.config_file
  end

  def each(&block)
    hash = @hash.dup
    hash.delete :update_sources
    hash.delete :verbose
    hash.delete :backtrace
    hash.delete :bulk_threshold

    yield :update_sources, @update_sources
    yield :verbose, @verbose
    yield :backtrace, @backtrace
    yield :bulk_threshold, @bulk_threshold

    yield 'config_file_name', @config_file_name if @config_file_name

    hash.each(&block)
  end

  def handle_arguments(arg_list)
    @args = []

    arg_list.each do |arg|
      case arg
      when /^--(backtrace|traceback)$/ then
        @backtrace = true
      when /^--debug$/ then
        $DEBUG = true

        warn 'NOTE:  Debugging mode prints all exceptions even when rescued'
      else
        @args << arg
      end
    end
  end

  def really_verbose
    case verbose
    when true, false, nil then
      false
    else
      true
    end
  end

  def to_yaml # :nodoc:
    yaml_hash = {}
    yaml_hash[:backtrace] = if @hash.key?(:backtrace)
                              @hash[:backtrace]
                            else
                              DEFAULT_BACKTRACE
                            end

    yaml_hash[:bulk_threshold] = if @hash.key?(:bulk_threshold)
                                   @hash[:bulk_threshold]
                                 else
                                   DEFAULT_BULK_THRESHOLD
                                 end

    yaml_hash[:sources] = Gem.sources.to_a

    yaml_hash[:update_sources] = if @hash.key?(:update_sources)
                                   @hash[:update_sources]
                                 else
                                   DEFAULT_UPDATE_SOURCES
                                 end

    yaml_hash[:verbose] = if @hash.key?(:verbose)
                            @hash[:verbose]
                          else
                            DEFAULT_VERBOSITY
                          end

    yaml_hash[:ssl_verify_mode] =
      @hash[:ssl_verify_mode] if @hash.key? :ssl_verify_mode

    yaml_hash[:ssl_ca_cert] =
      @hash[:ssl_ca_cert] if @hash.key? :ssl_ca_cert

    yaml_hash[:ssl_client_cert] =
      @hash[:ssl_client_cert] if @hash.key? :ssl_client_cert

    keys = yaml_hash.keys.map { |key| key.to_s }
    keys << 'debug'
    re = Regexp.union(*keys)

    @hash.each do |key, value|
      key = key.to_s
      next if key =~ re
      yaml_hash[key.to_s] = value
    end

    yaml_hash.to_yaml
  end

  def write
    open config_file_name, 'w' do |io|
      io.write to_yaml
    end
  end

  def [](key)
    @hash[key.to_s]
  end

  def []=(key, value)
    @hash[key.to_s] = value
  end

  def ==(other) # :nodoc:
    self.class === other and
      @backtrace == other.backtrace and
      @bulk_threshold == other.bulk_threshold and
      @verbose == other.verbose and
      @update_sources == other.update_sources and
      @hash == other.hash
  end

  attr_reader :hash
  protected :hash
end
