require 'log4r'

require "vagrant/util/safe_puts"

module Vagrant
  module Plugin
    module V2
      class Command
        include Util::SafePuts

        def self.synopsis
          ""
        end

        def initialize(argv, env)
          @argv = argv
          @env  = env
          @logger = Log4r::Logger.new("vagrant::command::#{self.class.to_s.downcase}")
        end

        def execute
        end

        protected

        def parse_options(opts=nil)
          argv = @argv.dup

          opts ||= OptionParser.new

          opts.on_tail("-h", "--help", "Print this help") do
            safe_puts(opts.help)
            return nil
          end

          opts.parse!(argv)
          return argv
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument
          raise Errors::CLIInvalidOptions, help: opts.help.chomp
        end

        def with_target_vms(names=nil, options=nil)
          @logger.debug("Getting target VMs for command. Arguments:")
          @logger.debug(" -- names: #{names.inspect}")
          @logger.debug(" -- options: #{options.inspect}")

          options ||= {}

          names ||= []
          names = [names] if !names.is_a?(Array)

          requires_local_env = false
          requires_local_env = true if names.empty?
          requires_local_env ||= names.any? { |n|
            !@env.machine_index.include?(n)
          }
          raise Errors::NoEnvironmentError if requires_local_env && !@env.root_path

          active_machines = @env.active_machines

          get_machine = lambda do |name|
            provider_to_use = options[:provider]
            provider_to_use = provider_to_use.to_sym if provider_to_use

            entry = @env.machine_index.get(name.to_s)
            if entry
              @env.machine_index.release(entry)

              env = entry.vagrant_env(
                @env.home_path, ui_class: @env.ui_class)
              next env.machine(entry.name.to_sym, entry.provider.to_sym)
            end

            active_machines.each do |active_name, active_provider|
              if name == active_name

                if provider_to_use && provider_to_use != active_provider
                  raise Errors::ActiveMachineWithDifferentProvider,
                    name: active_name.to_s,
                    active_provider: active_provider.to_s,
                    requested_provider: provider_to_use.to_s
                else
                  @logger.info("Active machine found with name #{active_name}. " +
                               "Using provider: #{active_provider}")
                  provider_to_use = active_provider
                  break
                end
              end
            end

            provider_to_use ||= @env.default_provider(machine: name)

            @env.machine(name, provider_to_use)
          end

          machines = []
          if names.length > 0
            names.each do |name|
              if pattern = name[/^\/(.+?)\/$/, 1]
                @logger.debug("Finding machines that match regex: #{pattern}")

                regex = Regexp.new(pattern)

                @env.machine_names.each do |machine_name|
                  if machine_name =~ regex
                    machines << get_machine.call(machine_name)
                  end
                end

                raise Errors::VMNoMatchError if machines.empty?
              else
                @logger.debug("Finding machine that match name: #{name}")
                machines << get_machine.call(name.to_sym)
                raise Errors::VMNotFoundError, name: name if !machines[0]
              end
            end
          else
            @logger.debug("Loading all machines...")
            machines = @env.machine_names.map do |machine_name|
              get_machine.call(machine_name)
            end
          end

          if options[:single_target] && machines.length != 1
            @logger.debug("Using primary machine since single target")
            primary_name = @env.primary_machine_name
            raise Errors::MultiVMTargetRequired if !primary_name
            machines = [get_machine.call(primary_name)]
          end

          machines.reverse! if options[:reverse]

          color_order = [:default]
          color_index = 0

          machines.each do |machine|
            machine.ui.opts[:color] = color_order[color_index % color_order.length]
            color_index += 1

            @logger.info("With machine: #{machine.name} (#{machine.provider.inspect})")
            yield machine

            begin
              machine.state
            rescue Errors::VagrantError
            end
          end
        end

        def split_main_and_subcommand(argv)
          main_args   = nil
          sub_command = nil
          sub_args    = []

          argv.each_index do |i|
            if !argv[i].start_with?("-")
              main_args   = argv[0, i]
              sub_command = argv[i]
              sub_args    = argv[i + 1, argv.length - i + 1]

              break
            end
          end

          main_args = argv.dup if main_args.nil?

          return [main_args, sub_command, sub_args]
        end
      end
    end
  end
end
