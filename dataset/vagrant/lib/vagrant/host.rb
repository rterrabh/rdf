require "vagrant/capability_host"

module Vagrant
  class Host
    include CapabilityHost

    def initialize(host, hosts, capabilities, env)
      initialize_capabilities!(host, hosts, capabilities, env)
    end
  end
end
