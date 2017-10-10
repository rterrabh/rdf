module ActiveAdmin
  module Inputs
    module Filters
      class CheckBoxesInput < ::Formtastic::Inputs::CheckBoxesInput
        include Base

        def input_name
          "#{object_name}[#{searchable_method_name}_in][]"
        end

        def selected_values
          #nodyna <send-64> <SD COMPLEX (change-prone variables)>
          @object.public_send("#{searchable_method_name}_in") || []
        end

        def searchable_method_name
          if searchable_has_many_through?
            "#{reflection.through_reflection.name}_#{reflection.foreign_key}"
          else
            association_primary_key || method
          end
        end

        def choice_label(choice)
          ' ' + super
        end

        def choices_group_wrapping(&block)
          template.capture(&block)
        end

        def choice_wrapping(html_options, &block)
          template.capture(&block)
        end

        def hidden_field_for_all
          ""
        end

        def hidden_fields?
          false
        end
      end
    end
  end
end
