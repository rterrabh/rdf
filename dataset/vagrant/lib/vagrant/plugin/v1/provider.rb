module Vagrant
  module Plugin
    module V1
      class Provider
        def initialize(machine)
        end

        def action(name)
          nil
        end

        def machine_id_changed
        end

        def ssh_info
          nil
        end

        def state
          nil
        end
      end
    end
  end
end
