module SimpleForm
  module Inputs
    class CollectionCheckBoxesInput < CollectionRadioButtonsInput
      protected

      def has_required?
        false
      end

      def build_nested_boolean_style_item_tag(collection_builder)
        collection_builder.check_box + collection_builder.text
      end

      def item_wrapper_class
        "checkbox"
      end
    end
  end
end
