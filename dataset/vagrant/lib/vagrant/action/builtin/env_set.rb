module Vagrant
  module Action
    module Builtin
      class EnvSet
        def initialize(app, env, new_env=nil)
          @app     = app
          @new_env = new_env || {}
        end

        def call(env)
          env.merge!(@new_env)

          @app.call(env)
        end
      end
    end
  end
end
