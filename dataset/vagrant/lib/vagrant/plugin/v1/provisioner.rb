module Vagrant
  module Plugin
    module V1
      class Provisioner
        attr_reader :env

        attr_reader :config

        def initialize(env, config)
          @env    = env
          @config = config
        end

        def self.config_class
        end

        def prepare
        end

        def provision!
        end

        def cleanup
        end
      end
    end
  end
end
