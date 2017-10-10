module Vagrant
  module Action
    module Builtin
      class IsState
        def initialize(app, env, check, **opts)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::action::builtin::is_state")
          @check  = check
          @invert = !!opts[:invert]
        end

        def call(env)
          @logger.debug("Checking if machine state is '#{@check}'")
          state = env[:machine].state.id
          @logger.debug("-- Machine state: #{state}")

          env[:result] = @check == state
          env[:result] = !env[:result] if @invert
          @app.call(env)
        end
      end
    end
  end
end
