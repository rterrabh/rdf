module Vagrant
  module CapabilityHost
    def initialize_capabilities!(host, hosts, capabilities, *args)
      @cap_logger = Log4r::Logger.new(
        "vagrant::capability_host::#{self.class.to_s.downcase}")

      if host && !hosts[host]
        raise Errors::CapabilityHostExplicitNotDetected, value: host.to_s
      end

      if !host
        host = autodetect_capability_host(hosts, *args) if !host
        raise Errors::CapabilityHostNotDetected if !host
      end

      if !hosts[host]
        raise "Internal error. Host not found: #{host}"
      end

      name      = host
      host_info = hosts[name]
      host      = host_info[0].new
      chain     = []
      chain << [name, host]

      if host_info[1]
        parent_name = host_info[1]
        parent_info = hosts[parent_name]
        while parent_info
          chain << [parent_name, parent_info[0].new]
          parent_name = parent_info[1]
          parent_info = hosts[parent_name]
        end
      end

      @cap_host_chain = chain
      @cap_args       = args
      @cap_caps       = capabilities
      true
    end

    def capability_host_chain
      @cap_host_chain
    end

    def capability?(cap_name)
      !capability_module(cap_name.to_sym).nil?
    end

    def capability(cap_name, *args)
      cap_mod = capability_module(cap_name.to_sym)
      if !cap_mod
        raise Errors::CapabilityNotFound,
          cap:  cap_name.to_s,
          host: @cap_host_chain[0][0].to_s
      end

      cap_method = nil
      begin
        cap_method = cap_mod.method(cap_name)
      rescue NameError
        raise Errors::CapabilityInvalid,
          cap: cap_name.to_s,
          host: @cap_host_chain[0][0].to_s
      end

      args = @cap_args + args
      @cap_logger.info(
        "Execute capability: #{cap_name} #{args.inspect} (#{@cap_host_chain[0][0]})")
      cap_method.call(*args)
    end

    protected

    def autodetect_capability_host(hosts, *args)
      @cap_logger.info("Autodetecting host type for #{args.inspect}")

      parent_count = {}
      hosts.each do |name, parts|
        parent_count[name] = 0

        parent = parts[1]
        while parent
          parent_count[name] += 1
          parent = hosts[parent]
          parent = parent[1] if parent
        end
      end

      parent_count_to_hosts = {}
      parent_count.each do |name, count|
        parent_count_to_hosts[count] ||= []
        parent_count_to_hosts[count] << name
      end

      sorted_counts = parent_count_to_hosts.keys.sort.reverse
      sorted_counts.each do |count|
        parent_count_to_hosts[count].each do |name|
          @cap_logger.debug("Trying: #{name}")
          host_info = hosts[name]
          host      = host_info[0].new

          if host.detect?(*args)
            @cap_logger.info("Detected: #{name}!")
            return name
          end
        end
      end

      return nil
    end

    def capability_module(cap_name)
      @cap_logger.debug("Searching for cap: #{cap_name}")
      @cap_host_chain.each do |host_name, host|
        @cap_logger.debug("Checking in: #{host_name}")
        caps = @cap_caps[host_name]

        if caps && caps.key?(cap_name)
          @cap_logger.debug("Found cap: #{cap_name} in #{host_name}")
          return caps[cap_name]
        end
      end

      nil
    end
  end
end
