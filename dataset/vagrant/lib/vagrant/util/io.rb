require "vagrant/util/platform"

module Vagrant
  module Util
    class IO
      READ_CHUNK_SIZE = 4096

      def self.read_until_block(io)
        data = ""

        while true
          begin
            if Platform.windows?

              results = ::IO.select([io], nil, nil, 1.0)
              break if !results || results[0].empty?

              data << io.readpartial(READ_CHUNK_SIZE).encode("UTF-8", Encoding.default_external)
            else
              data << io.read_nonblock(READ_CHUNK_SIZE)
            end
          rescue Exception => e

            breakable = false
            if e.is_a?(EOFError)
              breakable = true
            elsif defined?(::IO::WaitReadable) && e.is_a?(::IO::WaitReadable)

              breakable = true
            elsif e.is_a?(Errno::EAGAIN)
              breakable = true
            end

            break if breakable
            raise
          end
        end

        data
      end

    end
  end
end
