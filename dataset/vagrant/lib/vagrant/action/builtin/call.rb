module Vagrant
  module Action
    module Builtin
      class Call
        def initialize(app, env, callable, *callable_args, &block)
          raise ArgumentError, "A block must be given to Call" if !block

          @app      = app
          @callable = callable
          @callable_args = callable_args
          @block    = block
          @child_app = nil
        end

        def call(env)
          runner  = Runner.new

          callable = Builder.build(@callable, *@callable_args)

          new_env = runner.run(callable, env)

          builder = Builder.new
          @block.call(new_env, builder)

          builder.use @app
          @child_app = builder.to_app(new_env)
          final_env  = runner.run(@child_app, new_env)

          env.merge!(final_env)
        end

        def recover(env)
          @child_app.recover(env) if @child_app
        end
      end
    end
  end
end
