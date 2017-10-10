require 'log4r'

require "vagrant/util/safe_puts"

module Vagrant
  module Plugin
    module V1
      class Command
        include Util::SafePuts

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
        rescue OptionParser::InvalidOption
          raise Errors::CLIInvalidOptions, help: opts.help.chomp
        end

        def with_target_vms(names=nil, options=nil)
          raise Errors::NoEnvironmentError if !@env.root_path

          options ||= {}

          names ||= []
          names = [names] if !names.is_a?(Array)

          vms = []
          if names.length > 0
            names.each do |name|
              if pattern = name[/^\/(.+?)\/$/, 1]
                regex = Regexp.new(pattern)

                @env.vms.each do |name, vm|
                  vms << vm if name =~ regex
                end

                raise Errors::VMNoMatchError if vms.empty?
              else
                vms << @env.vms[name.to_sym]
                raise Errors::VMNotFoundError, name: name if !vms[0]
              end
            end
          else
            vms = @env.vms_ordered
          end

          if options[:single_target] && vms.length != 1
            vm = @env.primary_vm
            raise Errors::MultiVMTargetRequired if !vm
            vms = [vm]
          end

          vms.reverse! if options[:reverse]

          vms.each do |old_vm|
            vm = @env.vms[old_vm.name]
            yield vm
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
