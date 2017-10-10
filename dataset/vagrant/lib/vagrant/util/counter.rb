require 'thread'

module Vagrant
  module Util
    module Counter
      def get_and_update_counter(name=nil)
        name ||= :global

        mutex.synchronize do
          @__counter ||= Hash.new(1)
          result = @__counter[name]
          @__counter[name] += 1
          result
        end
      end

      def mutex
        @__counter_mutex ||= Mutex.new
      end
    end
  end
end
