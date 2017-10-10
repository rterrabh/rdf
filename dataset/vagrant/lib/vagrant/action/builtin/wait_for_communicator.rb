module Vagrant
  module Action
    module Builtin
      class WaitForCommunicator
        def initialize(app, env, states=nil)
          @app    = app
          @states = states
        end

        def call(env)
          ready_thr = Thread.new do
            Thread.current[:result] = env[:machine].communicate.wait_for_ready(
              env[:machine].config.vm.boot_timeout)
          end

          states_thr = Thread.new do
            Thread.current[:result] = true

            while true
              state = env[:machine].state.id

              Thread.current[:last_known_state] = state

              if @states && !@states.include?(state)
                Thread.current[:result] = false
                break
              end

              sleep 1
            end
          end

          env[:ui].output(I18n.t("vagrant.boot_waiting"))
          while ready_thr.alive? && states_thr.alive?
            sleep 1
            return if env[:interrupted]
          end

          ready_thr.join if !ready_thr.alive?
          states_thr.join if !states_thr.alive?

          if !states_thr[:result]
            raise Errors::VMBootBadState,
              valid: @states.join(", "),
              invalid: states_thr[:last_known_state]
          end

          if !ready_thr[:result]
            raise Errors::VMBootTimeout
          end

          env[:ui].output(I18n.t("vagrant.boot_completed"))

          ready_thr.kill
          states_thr.kill

          @app.call(env)
        ensure
          ready_thr.kill
          states_thr.kill
        end
      end
    end
  end
end
