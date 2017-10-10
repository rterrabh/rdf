require "socket"
require "timeout"

module Vagrant
  module Util
    module IsPortOpen
      def is_port_open?(host, port)
        Timeout.timeout(1) do
          s = TCPSocket.new(host, port)

          s.close rescue nil

          return true
        end
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, \
             Errno::ENETUNREACH, Errno::EACCES
        return false
      end
    end
  end
end
