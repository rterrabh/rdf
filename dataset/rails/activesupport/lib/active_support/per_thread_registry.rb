module ActiveSupport
  module PerThreadRegistry
    def self.extended(object)
      #nodyna <instance_variable_set-998> <IVS COMPLEX (variable definition)>
      object.instance_variable_set '@per_thread_registry_key', object.name.freeze
    end

    def instance
      Thread.current[@per_thread_registry_key] ||= new
    end

    protected
      def method_missing(name, *args, &block) # :nodoc:
        define_singleton_method(name) do |*a, &b|
          #nodyna <send-999> <SD COMPLEX (change-prone variables)>
          instance.public_send(name, *a, &b)
        end

        #nodyna <send-1000> <SD COMPLEX (change-prone variables)>
        send(name, *args, &block)
      end
  end
end
