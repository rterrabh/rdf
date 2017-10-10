require "vagrant/capability_host"

module Vagrant
  module Plugin
    module V2
      class Provider
        include CapabilityHost

        def self.usable?(raise_error=false)
          true
        end

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

        def _initialize(name, machine)
          initialize_capabilities!(
            name.to_sym,
            { name.to_sym => [Class.new, nil] },
            Vagrant.plugin("2").manager.provider_capabilities,
            machine,
          )
        end
      end
    end
  end
end
