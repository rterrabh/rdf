require "log4r"

require "vagrant/capability_host"

module Vagrant
  class Guest
    include CapabilityHost

    def initialize(machine, guests, capabilities)
      @capabilities = capabilities
      @guests       = guests
      @machine      = machine
    end

    def detect!
      guest_name = @machine.config.vm.guest
      initialize_capabilities!(guest_name, @guests, @capabilities, @machine)
    rescue Errors::CapabilityHostExplicitNotDetected => e
      raise Errors::GuestExplicitNotDetected, value: e.extra_data[:value]
    rescue Errors::CapabilityHostNotDetected
      raise Errors::GuestNotDetected
    end

    def capability(*args)
      super
    rescue Errors::CapabilityNotFound => e
      raise Errors::GuestCapabilityNotFound,
        cap: e.extra_data[:cap],
        guest: name
    rescue Errors::CapabilityInvalid => e
      raise Errors::GuestCapabilityInvalid,
        cap: e.extra_data[:cap],
        guest: name
    end

    def name
      capability_host_chain[0][0]
    end

    def ready?
      !!capability_host_chain
    end
  end
end
