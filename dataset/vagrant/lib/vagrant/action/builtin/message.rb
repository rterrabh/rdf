module Vagrant
  module Action
    module Builtin
      class Message
        def initialize(app, env, message, **opts)
          @app     = app
          @message = message
          @opts    = opts
        end

        def call(env)
          if !@opts[:post]
            env[:ui].output(@message)
          end

          @app.call(env)

          if @opts[:post]
            env[:ui].output(@message)
          end
        end
      end
    end
  end
end
