module ActiveAdmin
  module Deprecation
    module_function

    def warn(message, callstack = caller)
      ActiveSupport::Deprecation.warn "Active Admin: #{message}", callstack
    end

    # Deprecate a method.
    #
    # @param [Module] klass the Class or Module to deprecate the method on
    # @param [Symbol] method the method to deprecate
    # @param [String] message the message to display to the end user
    #
    # Example:
    #
    #     class MyClass
    #       def my_method
    #         # ...
    #       end
    #       ActiveAdmin::Deprecation.deprecate self, :my_method,
    #         "MyClass#my_method is being removed in the next release"
    #     end
    #
    def deprecate(klass, method, message)
      #nodyna <ID:send-31> <send VERY HIGH ex4>
      #nodyna <ID:define_method-6> <define_method VERY HIGH ex2>
      klass.send :define_method, "deprecated_#{method}", klass.instance_method(method)

      #nodyna <ID:send-32> <send VERY HIGH ex4>
      #nodyna <ID:define_method-7> <define_method VERY HIGH ex2>
      klass.send :define_method, method do |*args|
        ActiveAdmin::Deprecation.warn "#{message}", caller
        #nodyna <ID:send-33> <send VERY HIGH ex3>
        send "deprecated_#{method}", *args
      end
    end

  end
end
