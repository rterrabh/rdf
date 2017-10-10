module ActiveAdmin
  module ViewHelpers
    module DisplayHelper

      DISPLAY_NAME_FALLBACK = ->{
        name, klass = "", self.class
        name << klass.model_name.human         if klass.respond_to? :model_name
        #nodyna <send-101> <SD COMPLEX (change-prone variables)>
        name << " ##{send(klass.primary_key)}" if klass.respond_to? :primary_key
        name.present? ? name : to_s
      }
      def DISPLAY_NAME_FALLBACK.inspect
        'DISPLAY_NAME_FALLBACK'
      end

      def display_name(resource)
        render_in_context resource, display_name_method_for(resource) if resource
      end

      def display_name_method_for(resource)
        @@display_name_methods_cache ||= {}
        @@display_name_methods_cache[resource.class] ||= begin
          methods = active_admin_application.display_name_methods - association_methods_for(resource)
          method  = methods.detect{ |method| resource.respond_to? method }

          if method != :to_s || resource.method(method).source_location
            method
          else
            DISPLAY_NAME_FALLBACK
          end
        end
      end

      def association_methods_for(resource)
        return [] unless resource.class.respond_to? :reflect_on_all_associations
        resource.class.reflect_on_all_associations.map(&:name)
      end

      def pretty_format(object)
        case object
        when String, Numeric, Arbre::Element
          object.to_s
        when Date, Time
          localize object, format: :long
        else
          if defined?(::ActiveRecord) && object.is_a?(ActiveRecord::Base) ||
             defined?(::Mongoid)      && object.class.include?(Mongoid::Document)
            auto_link object
          else
            display_name object
          end
        end
      end

    end
  end
end
