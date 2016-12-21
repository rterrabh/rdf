module Spree
  module Core
    module EnvironmentExtension
      extend ActiveSupport::Concern

      def add_class(name)
        self.instance_variable_set "@#{name}", Set.new

        create_method( "#{name}=".to_sym ) { |val|
          instance_variable_set( "@" + name, val)
        }

        create_method(name.to_sym) do
          instance_variable_get( "@" + name )
        end
      end

      private

        def create_method(name, &block)
          #nodyna <ID:send-6> <send MEDIUM ex4>
          #nodyna <ID:define_method-2> <define_method VERY HIGH ex2>
          self.class.send(:define_method, name, &block)
        end
    end
  end
end
