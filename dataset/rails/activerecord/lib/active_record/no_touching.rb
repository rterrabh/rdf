module ActiveRecord
  module NoTouching
    extend ActiveSupport::Concern

    module ClassMethods
      def no_touching(&block)
        NoTouching.apply_to(self, &block)
      end
    end

    class << self
      def apply_to(klass) #:nodoc:
        klasses.push(klass)
        yield
      ensure
        klasses.pop
      end

      def applied_to?(klass) #:nodoc:
        klasses.any? { |k| k >= klass }
      end

      private
        def klasses
          Thread.current[:no_touching_classes] ||= []
        end
    end

    def no_touching?
      NoTouching.applied_to?(self.class)
    end

    def touch(*) # :nodoc:
      super unless no_touching?
    end
  end
end
