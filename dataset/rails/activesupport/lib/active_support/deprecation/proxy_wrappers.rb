require 'active_support/inflector/methods'

module ActiveSupport
  class Deprecation
    class DeprecationProxy #:nodoc:
      def self.new(*args, &block)
        object = args.first

        return object unless object
        super
      end

      instance_methods.each { |m| undef_method m unless m =~ /^__|^object_id$/ }

      def inspect
        target.inspect
      end

      private
        def method_missing(called, *args, &block)
          warn caller, called, args
          target.__send__(called, *args, &block)
        end
    end

    class DeprecatedObjectProxy < DeprecationProxy
      def initialize(object, message, deprecator = ActiveSupport::Deprecation.instance)
        @object = object
        @message = message
        @deprecator = deprecator
      end

      private
        def target
          @object
        end

        def warn(callstack, called, args)
          @deprecator.warn(@message, callstack)
        end
    end

    class DeprecatedInstanceVariableProxy < DeprecationProxy
      def initialize(instance, method, var = "@#{method}", deprecator = ActiveSupport::Deprecation.instance)
        @instance = instance
        @method = method
        @var = var
        @deprecator = deprecator
      end

      private
        def target
          @instance.__send__(@method)
        end

        def warn(callstack, called, args)
          @deprecator.warn("#{@var} is deprecated! Call #{@method}.#{called} instead of #{@var}.#{called}. Args: #{args.inspect}", callstack)
        end
    end

    class DeprecatedConstantProxy < DeprecationProxy
      def initialize(old_const, new_const, deprecator = ActiveSupport::Deprecation.instance)
        @old_const = old_const
        @new_const = new_const
        @deprecator = deprecator
      end

      def class
        target.class
      end

      private
        def target
          ActiveSupport::Inflector.constantize(@new_const.to_s)
        end

        def warn(callstack, called, args)
          @deprecator.warn("#{@old_const} is deprecated! Use #{@new_const} instead.", callstack)
        end
    end
  end
end
