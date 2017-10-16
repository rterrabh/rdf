module Spree
  module Core
    module EnvironmentExtension
      extend ActiveSupport::Concern

      def add_class(name)
        #nodyna <instance_variable_set-2581> <IVS MODERATE (change-prone variable)>
        self.instance_variable_set "@#{name}", Set.new

        create_method( "#{name}=".to_sym ) { |val|
          #nodyna <instance_variable_set-2582> <IVS MODERATE (change-prone variable)>
          instance_variable_set( "@" + name, val)
        }

        create_method(name.to_sym) do
          #nodyna <instance_variable_get-2583> <IVG MODERATE (change-prone variable)>
          instance_variable_get( "@" + name )
        end
      end

      private

        def create_method(name, &block)
          #nodyna <send-2584> <SD MODERATE (private methods)>
          #nodyna <define_method-2585> <DM COMPLEX (events)>
          self.class.send(:define_method, name, &block)
        end
    end
  end
end
