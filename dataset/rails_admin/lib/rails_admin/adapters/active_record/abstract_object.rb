module RailsAdmin
  module Adapters
    module ActiveRecord
      class AbstractObject
        instance_methods.each { |m| undef_method m unless m.to_s =~ /(^__|^send$|^object_id$)/ }

        attr_accessor :object

        def initialize(object)
          self.object = object
        end

        def set_attributes(attributes)
          object.assign_attributes(attributes) if attributes
        end

        def save(options = {validate: true})
          object.save(options)
        end

        def method_missing(name, *args, &block)
          #nodyna <send-1337> <SD COMPLEX (change-prone variables)>
          object.send(name, *args, &block)
        end
      end
    end
  end
end
