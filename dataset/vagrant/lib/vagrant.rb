require "vagrant/shared_helpers"

if Vagrant.plugins_enabled? && !defined?(Bundler)
  puts "It appears that Vagrant was not properly loaded. Specifically,"
  puts "the bundler context Vagrant requires was not setup. Please execute"
  puts "vagrant using only the `vagrant` executable."
  abort
end

require 'rubygems'
require 'log4r'

if ENV["VAGRANT_LOG"] && ENV["VAGRANT_LOG"] != ""
  require 'log4r/config'
  Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

  level = nil
  begin
    #nodyna <const_get-3061> <CG COMPLEX (change-prone variables)>
    level = Log4r.const_get(ENV["VAGRANT_LOG"].upcase)
  rescue NameError
    level = nil
  end

  level = nil if !level.is_a?(Integer)

  if !level
    $stderr.puts "Invalid VAGRANT_LOG level is set: #{ENV["VAGRANT_LOG"]}"
    $stderr.puts ""
    $stderr.puts "Please use one of the standard log levels: debug, info, warn, or error"
    exit 1
  end

  if level
    logger = Log4r::Logger.new("vagrant")
    logger.outputters = Log4r::Outputter.stderr
    logger.level = level
    logger = nil
  end
end

require 'json'
require 'pathname'
require 'stringio'

require 'childprocess'
require 'i18n'

require 'openssl'

require 'vagrant/version'
global_logger = Log4r::Logger.new("vagrant::global")
global_logger.info("Vagrant version: #{Vagrant::VERSION}")
global_logger.info("Ruby version: #{RUBY_VERSION}")
global_logger.info("RubyGems version: #{Gem::VERSION}")
ENV.each do |k, v|
  global_logger.info("#{k}=#{v.inspect}") if k =~ /^VAGRANT_/
end
global_logger.info("Plugins:")
Bundler.definition.specs_for([:plugins]).each do |spec|
  global_logger.info("  - #{spec.name} = #{spec.version}")
end


require "vagrant/plugin"
require "vagrant/registry"

module Vagrant
  autoload :Action,        'vagrant/action'
  autoload :BatchAction,   'vagrant/batch_action'
  autoload :Box,           'vagrant/box'
  autoload :BoxCollection, 'vagrant/box_collection'
  autoload :CLI,           'vagrant/cli'
  autoload :Command,       'vagrant/command'
  autoload :Config,        'vagrant/config'
  autoload :Driver,        'vagrant/driver'
  autoload :Environment,   'vagrant/environment'
  autoload :Errors,        'vagrant/errors'
  autoload :Guest,         'vagrant/guest'
  autoload :Host,          'vagrant/host'
  autoload :Machine,       'vagrant/machine'
  autoload :MachineIndex,  'vagrant/machine_index'
  autoload :MachineState,  'vagrant/machine_state'
  autoload :Plugin,        'vagrant/plugin'
  autoload :UI,            'vagrant/ui'
  autoload :Util,          'vagrant/util'

  PLUGIN_COMPONENTS = Registry.new.tap do |c|
    c.register(:"1")                  { Plugin::V1::Plugin }
    c.register([:"1", :command])      { Plugin::V1::Command }
    c.register([:"1", :communicator]) { Plugin::V1::Communicator }
    c.register([:"1", :config])       { Plugin::V1::Config }
    c.register([:"1", :guest])        { Plugin::V1::Guest }
    c.register([:"1", :host])         { Plugin::V1::Host }
    c.register([:"1", :provider])     { Plugin::V1::Provider }
    c.register([:"1", :provisioner])  { Plugin::V1::Provisioner }

    c.register(:"2")                  { Plugin::V2::Plugin }
    c.register([:"2", :command])      { Plugin::V2::Command }
    c.register([:"2", :communicator]) { Plugin::V2::Communicator }
    c.register([:"2", :config])       { Plugin::V2::Config }
    c.register([:"2", :guest])        { Plugin::V2::Guest }
    c.register([:"2", :host])         { Plugin::V2::Host }
    c.register([:"2", :provider])     { Plugin::V2::Provider }
    c.register([:"2", :provisioner])  { Plugin::V2::Provisioner }
    c.register([:"2", :push])         { Plugin::V2::Push }
    c.register([:"2", :synced_folder]) { Plugin::V2::SyncedFolder }
  end

  def self.configure(version, &block)
    Config.run(version, &block)
  end

  def self.has_plugin?(name, version=nil)
    return false unless Vagrant.plugins_enabled?

    if !version
      return true if plugin("2").manager.registered.any? { |p| p.name == name }
    end

    version = Gem::Requirement.new([version]) if version

    require "vagrant/plugin/manager"
    Plugin::Manager.instance.installed_specs.any? do |s|
      match = s.name == name
      next match if !version
      next match && version.satisfied_by?(s.version)
    end
  end

  def self.plugin(version, component=nil)
    key    = version.to_s.to_sym
    key    = [key, component.to_s.to_sym] if component
    result = PLUGIN_COMPONENTS.get(key)

    return result if result

    raise ArgumentError, "Plugin superclass not found for version/component: " +
      "#{version} #{component}"
  end

  def self.require_plugin(name)
    puts "Vagrant.require_plugin is deprecated and has no effect any longer."
    puts "Use `vagrant plugin` commands to manage plugins. This warning will"
    puts "be removed in the next version of Vagrant."
  end

  def self.require_version(*requirements)
    logger = Log4r::Logger.new("vagrant::root")
    logger.info("Version requirements from Vagrantfile: #{requirements.inspect}")

    req = Gem::Requirement.new(*requirements)
    if req.satisfied_by?(Gem::Version.new(VERSION))
      logger.info("  - Version requirements satisfied!")
      return
    end

    raise Errors::VagrantVersionBad,
      requirements: requirements.join(", "),
      version: VERSION
  end

  def self.original_env
    {}.tap do |h|
      ENV.each do |k,v|
        if k.start_with?("VAGRANT_OLD_ENV")
          key = k.sub(/^VAGRANT_OLD_ENV_/, "")
          h[key] = v
        end
      end
    end
  end
end

I18n.load_path << File.expand_path("templates/locales/en.yml", Vagrant.source_root)

if I18n.config.respond_to?(:enforce_available_locales=)
  I18n.config.enforce_available_locales = true
end

plugin_load_proc = lambda do |directory|
  next false if !directory.directory?

  plugin_file = directory.join("plugin.rb")
  if plugin_file.file?
    global_logger.debug("Loading core plugin: #{plugin_file}")
    load(plugin_file)
    next true
  end
end

Vagrant.source_root.join("plugins").children(true).each do |directory|
  next if !directory.directory?

  next if plugin_load_proc.call(directory)

  directory.children(true).each(&plugin_load_proc)
end

if Vagrant.plugins_enabled?
  begin
    global_logger.info("Loading plugins!")
    $vagrant_bundler_runtime.require(:plugins)
  rescue Exception => e
    raise Vagrant::Errors::PluginLoadError, message: e.to_s
  end
end
