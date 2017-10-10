module Vagrant
  module Util
    module SafePuts
      def safe_puts(message=nil, opts=nil)
        message ||= ""
        opts = {
          io: $stdout,
          printer: :puts
        }.merge(opts || {})

        begin
          #nodyna <send-3082> <SD MODERATE (change-prone variables)>
          opts[:io].send(opts[:printer], message)
        rescue Errno::EPIPE
          return
        end
      end
    end
  end
end

