module ActiveAdmin
  module Inputs
    module Filters
      class StringInput < ::Formtastic::Inputs::StringInput
        include Base
        include Base::SearchMethodSelect

        filter :contains, :equals, :starts_with, :ends_with

        def to_html
          if seems_searchable?
            input_wrapping do
              label_html <<
              builder.text_field(method, input_html_options)
            end
          else
            super # SearchMethodSelect#to_html
          end
        end

      end
    end
  end
end
