require 'ipaddr'

module ActionDispatch
  class RemoteIp
    class IpSpoofAttackError < StandardError; end

    TRUSTED_PROXIES = [
      "127.0.0.1",      # localhost IPv4
      "::1",            # localhost IPv6
      "fc00::/7",       # private IPv6 range fc00::/7
      "10.0.0.0/8",     # private IPv4 range 10.x.x.x
      "172.16.0.0/12",  # private IPv4 range 172.16.0.0 .. 172.31.255.255
      "192.168.0.0/16", # private IPv4 range 192.168.x.x
    ].map { |proxy| IPAddr.new(proxy) }

    attr_reader :check_ip, :proxies

    def initialize(app, check_ip_spoofing = true, custom_proxies = nil)
      @app = app
      @check_ip = check_ip_spoofing
      @proxies = if custom_proxies.blank?
        TRUSTED_PROXIES
      elsif custom_proxies.respond_to?(:any?)
        custom_proxies
      else
        Array(custom_proxies) + TRUSTED_PROXIES
      end
    end

    def call(env)
      env["action_dispatch.remote_ip"] = GetIp.new(env, self)
      @app.call(env)
    end

    class GetIp
      def initialize(env, middleware)
        @env      = env
        @check_ip = middleware.check_ip
        @proxies  = middleware.proxies
      end

      def calculate_ip
        remote_addr = ips_from('REMOTE_ADDR').last

        client_ips    = ips_from('HTTP_CLIENT_IP').reverse
        forwarded_ips = ips_from('HTTP_X_FORWARDED_FOR').reverse

        should_check_ip = @check_ip && client_ips.last && forwarded_ips.last
        if should_check_ip && !forwarded_ips.include?(client_ips.last)
          raise IpSpoofAttackError, "IP spoofing attack?! " +
            "HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect} " +
            "HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}"
        end

        ips = [forwarded_ips, client_ips, remote_addr].flatten.compact

        filter_proxies(ips).first || remote_addr
      end

      def to_s
        @ip ||= calculate_ip
      end

    protected

      def ips_from(header)
        ips = @env[header] ? @env[header].strip.split(/[,\s]+/) : []
        ips.select do |ip|
          begin
            range = IPAddr.new(ip).to_range
            range.begin == range.end
          rescue ArgumentError
            nil
          end
        end
      end

      def filter_proxies(ips)
        ips.reject do |ip|
          @proxies.any? { |proxy| proxy === ip }
        end
      end

    end

  end
end
