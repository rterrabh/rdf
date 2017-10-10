module ActiveAdmin
  module Deprecation
    module_function

    def warn(message, callstack = caller)
      ActiveSupport::Deprecation.warn "Active Admin: #{message}", callstack
    end

    def deprecate(klass, method, message)
      #nodyna <send-96> <SD COMPLEX (private methods)>
      #nodyna <define_method-97> <DM COMPLEX (events)>
      klass.send :define_method, "deprecated_#{method}", klass.instance_method(method)

      #nodyna <send-98> <SD COMPLEX (private methods)>
      #nodyna <define_method-99> <DM COMPLEX (events)>
      klass.send :define_method, method do |*args|
        ActiveAdmin::Deprecation.warn "#{message}", caller
        #nodyna <send-100> <SD COMPLEX (change-prone variables)>
        send "deprecated_#{method}", *args
      end
    end

  end
end
