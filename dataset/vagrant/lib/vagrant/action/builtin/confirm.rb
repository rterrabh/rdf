module Vagrant
  module Action
    module Builtin
      class Confirm
        def initialize(app, env, message, force_key=nil, **opts)
          @app      = app
          @message  = message
          @force_key = force_key
          @allowed  = opts[:allowed]
        end

        def call(env)
          choice = nil

          choice = "Y" if @force_key && env[@force_key]

          if !choice
            while true
              choice = env[:ui].ask(@message)

              break if !@allowed
              break if @allowed.include?(choice)
            end
          end

          env[:result] = choice && choice.upcase == "Y"
          env["#{@force_key}_result".to_sym] = env[:result]

          @app.call(env)
        end
      end
    end
  end
end
