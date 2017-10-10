require 'thread'

require "log4r"

module Vagrant
  class BatchAction
    def initialize(allow_parallel=true)
      @actions          = []
      @allow_parallel   = allow_parallel
      @logger           = Log4r::Logger.new("vagrant::batch_action")
    end

    def action(machine, action, options=nil)
      @actions << [machine, action, options]
    end

    def custom(machine, &block)
      @actions << [machine, block, nil]
    end

    def run
      par = false

      if @allow_parallel
        par = true
        @logger.info("Enabling parallelization by default.")
      end

      if par
        @actions.each do |machine, _, _|
          if !machine.provider_options[:parallel]
            @logger.info("Disabling parallelization because provider doesn't support it: #{machine.provider_name}")
            par = false
            break
          end
        end
      end

      if par && @actions.length <= 1
        @logger.info("Disabling parallelization because only executing one action")
        par = false
      end

      @logger.info("Batch action will parallelize: #{par.inspect}")

      threads = []
      @actions.each do |machine, action, options|
        @logger.info("Starting action: #{machine} #{action} #{options}")

        thread = Thread.new do
          Thread.current[:error] = nil

          start_pid = Process.pid

          begin
            if action.is_a?(Proc)
              action.call(machine)
            else
              #nodyna <send-3076> <SD TRIVIAL (public methods)>
              machine.send(:action, action, options)
            end
          rescue Exception => e
            raise if !par && Process.pid == start_pid

            Thread.current[:error] = e

            if Process.pid == start_pid
              machine.ui.error(I18n.t("vagrant.general.batch_notify_error"))
            end
          end

          if Process.pid != start_pid

            exit_status = true
            if Thread.current[:error]
              exit_status = false
              error = Thread.current[:error]
              @logger.error(error.inspect)
              @logger.error(error.message)
              @logger.error(error.backtrace.join("\n"))
            end

            Process.exit!(exit_status)
          end
        end

        thread[:machine] = machine

        thread.join if !par
        threads << thread
      end

      errors = []

      threads.each do |thread|
        thread.join

        if thread[:error]
          e = thread[:error]
          if !thread[:error].is_a?(Errors::VagrantError)
            e       = thread[:error]
            message = e.message
            message += "\n"
            message += "\n#{e.backtrace.join("\n")}"

            errors << I18n.t("vagrant.general.batch_unexpected_error",
                             machine: thread[:machine].name,
                             message: message)
          else
            errors << I18n.t("vagrant.general.batch_vagrant_error",
                             machine: thread[:machine].name,
                             message: thread[:error].message)
          end
        end
      end

      if !errors.empty?
        raise Errors::BatchMultiError, message: errors.join("\n\n")
      end
    end
  end
end
