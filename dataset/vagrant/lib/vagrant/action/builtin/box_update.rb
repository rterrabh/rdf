require "log4r"

module Vagrant
  module Action
    module Builtin
      class BoxUpdate
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new(
            "vagrant::action::builtin::box_update")
        end

        def call(env)
          machine = env[:machine]
        end
      end
    end
  end
end
