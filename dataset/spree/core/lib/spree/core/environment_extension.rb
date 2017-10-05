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
          #nodyna <ID:send-6> <SD MODERATE (private methods)>
          #nodyna <ID:define_method-2> <DM COMPLEX (events)>
          self.class.send(:define_method, name, &block)
        end
    end
  end
end
