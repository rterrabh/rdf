module Vagrant
  module Plugin
    module V2
      class Push
        attr_reader :env
        attr_reader :config

        def initialize(env, config)
          @env     = env
          @config  = config
        end

        def push
        end
      end
    end
  end
end
