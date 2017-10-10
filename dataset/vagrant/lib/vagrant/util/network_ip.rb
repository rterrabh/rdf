module Vagrant
  module Util
    module NetworkIP
      def network_address(ip, subnet)
        ip      = ip_parts(ip)
        netmask = ip_parts(subnet)

        ip.map { |part| part & netmask.shift }.join(".")
      end

      protected

      def ip_parts(ip)
        ip.split(".").map { |i| i.to_i }
      end
    end
  end
end
