require "log4r"
require "timeout"

module Vagrant
  module Action
    module Builtin
      class GracefulHalt
        def initialize(app, env, target_state, source_state=nil)
          @app          = app
          @logger       = Log4r::Logger.new("vagrant::action::builtin::graceful_halt")
          @source_state = source_state
          @target_state = target_state
        end

        def call(env)
          graceful = true
          graceful = !env[:force_halt] if env.key?(:force_halt)

          env[:result] = false

          if graceful && @source_state
            @logger.info("Verifying source state of machine: #{@source_state.inspect}")

            current_state = env[:machine].state.id
            if current_state != @source_state
              @logger.info("Invalid source state, not halting: #{current_state}")
              graceful = false
            end
          end

          if graceful
            env[:ui].output(I18n.t("vagrant.actions.vm.halt.graceful"))

            begin
              env[:machine].guest.capability(:halt)

              @logger.debug("Waiting for target graceful halt state: #{@target_state}")
              begin
                Timeout.timeout(env[:machine].config.vm.graceful_halt_timeout) do
                  while env[:machine].state.id != @target_state
                    sleep 1
                  end
                end
              rescue Timeout::Error
              end
            rescue Errors::GuestCapabilityNotFound
            rescue Errors::MachineGuestNotReady
              env[:ui].detail(I18n.t("vagrant.actions.vm.halt.guest_not_ready"))
            end

            env[:result] = env[:machine].state.id == @target_state

            if env[:result]
              @logger.info("Gracefully halted.")
            else
              @logger.info("Graceful halt failed.")
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
