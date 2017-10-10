module Vagrant
  module Plugin
    module V2
      class Provisioner
        attr_reader :machine
        attr_reader :config

        def initialize(machine, config)
          @machine = machine
          @config  = config
        end

        def configure(root_config)
        end

        def provision
        end

        def cleanup
        end
      end
    end
  end
end
