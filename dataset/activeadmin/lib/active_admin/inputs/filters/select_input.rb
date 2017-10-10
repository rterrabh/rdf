module ActiveAdmin
  module Inputs
    module Filters
      class SelectInput < ::Formtastic::Inputs::SelectInput
        include Base

        def input_name
          return method if seems_searchable?

          searchable_method_name.concat multiple? ? '_in' : '_eq'
        end

        def searchable_method_name
          if searchable_has_many_through?
            "#{reflection.through_reflection.name}_#{reflection.foreign_key}"
          else
            name = method.to_s
            name.concat '_id' if reflection
            name
          end
        end

        def include_blank
          I18n.t 'active_admin.any' if super
        end

        def input_html_options_name
          "#{object_name}[#{input_name}]" # was "#{object_name}[#{association_primary_key}]"
        end

        def multiple_by_association?
          false
        end

        def collection
          if !options[:collection] && column
            pluck_column
          else
            super
          end
        end

        def pluck_column
          klass.reorder("#{method} asc").uniq.pluck method
        end

      end
    end
  end
end
