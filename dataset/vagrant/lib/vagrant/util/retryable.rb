require "log4r"

module Vagrant
  module Util
    module Retryable
      def retryable(opts=nil)
        logger = nil
        opts   = { tries: 1, on: Exception }.merge(opts || {})

        begin
          return yield
        rescue *opts[:on] => e
          if (opts[:tries] -= 1) > 0
            logger = Log4r::Logger.new("vagrant::util::retryable")
            logger.info("Retryable exception raised: #{e.inspect}")

            sleep opts[:sleep].to_f if opts[:sleep]
            retry
          end
          raise
        end
      end
    end
  end
end
