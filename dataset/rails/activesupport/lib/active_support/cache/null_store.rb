module ActiveSupport
  module Cache
    class NullStore < Store
      def initialize(options = nil)
        super(options)
        extend Strategy::LocalCache
      end

      def clear(options = nil)
      end

      def cleanup(options = nil)
      end

      def increment(name, amount = 1, options = nil)
      end

      def decrement(name, amount = 1, options = nil)
      end

      def delete_matched(matcher, options = nil)
      end

      protected
        def read_entry(key, options) # :nodoc:
        end

        def write_entry(key, entry, options) # :nodoc:
          true
        end

        def delete_entry(key, options) # :nodoc:
          false
        end
    end
  end
end
