module ActiveAdmin
  module Filters
    module FormtasticAddons


      def humanized_method_name
        if klass.respond_to?(:human_attribute_name)
          klass.human_attribute_name(method)
        else
          #nodyna <send-13> <SD COMPLEX (change-prone variables)>
          method.to_s.public_send(builder.label_str_method)
        end
      end

      def reflection_for(method)
        klass.reflect_on_association(method) if klass.respond_to? :reflect_on_association
      end

      def column_for(method)
        klass.columns_hash[method.to_s] if klass.respond_to? :columns_hash
      end

      def column
        column_for method
      end


      def klass
        @object.object.klass
      end

      def polymorphic_foreign_type?(method)
        klass.reflect_on_all_associations.select{ |r| r.macro == :belongs_to && r.options[:polymorphic] }
          .map(&:foreign_type).include? method.to_s
      end


      def searchable_has_many_through?
        if reflection && reflection.options[:through]
          reflection.through_reflection.klass.ransackable_attributes.include? reflection.foreign_key
        else
          false
        end
      end

      def seems_searchable?
        has_predicate? || ransacker? || scope?
      end

      def has_predicate?
        !!Ransack::Predicate.detect_from_string(method.to_s)
      end

      def ransacker?
        klass._ransackers.key? method.to_s
      end

      def scope?
        context = Ransack::Context.for klass
        context.respond_to?(:ransackable_scope?) && context.ransackable_scope?(method.to_s, klass)
      end

    end
  end
end
