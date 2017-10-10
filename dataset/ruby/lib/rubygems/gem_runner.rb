
require 'rubygems'
require 'rubygems/command_manager'
require 'rubygems/config_file'


Gem.load_env_plugins rescue nil


class Gem::GemRunner

  def initialize(options={})
    @command_manager_class = options[:command_manager] || Gem::CommandManager
    @config_file_class = options[:config_file] || Gem::ConfigFile
  end


  def run args
    build_args = extract_build_args args

    do_configuration args

    cmd = @command_manager_class.instance

    cmd.command_names.each do |command_name|
      config_args = Gem.configuration[command_name]
      config_args = case config_args
                    when String
                      config_args.split ' '
                    else
                      Array(config_args)
                    end
      Gem::Command.add_specific_extra_args command_name, config_args
    end

    cmd.run Gem.configuration.args, build_args
  end


  def extract_build_args args # :nodoc:
    return [] unless offset = args.index('--')

    build_args = args.slice!(offset...args.length)

    build_args.shift

    build_args
  end

  private

  def do_configuration(args)
    Gem.configuration = @config_file_class.new(args)
    Gem.use_paths Gem.configuration[:gemhome], Gem.configuration[:gempath]
    Gem::Command.extra_args = Gem.configuration[:gem]
  end

end

Gem.load_plugins
