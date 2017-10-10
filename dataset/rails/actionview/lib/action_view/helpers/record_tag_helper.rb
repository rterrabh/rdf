require 'action_view/record_identifier'

module ActionView
  module Helpers
    module RecordTagHelper
      include ActionView::RecordIdentifier

      def div_for(record, *args, &block)
        content_tag_for(:div, record, *args, &block)
      end

      def content_tag_for(tag_name, single_or_multiple_records, prefix = nil, options = nil, &block)
        options, prefix = prefix, nil if prefix.is_a?(Hash)

        Array(single_or_multiple_records).map do |single_record|
          content_tag_for_single_record(tag_name, single_record, prefix, options, &block)
        end.join("\n").html_safe
      end

      private

        def content_tag_for_single_record(tag_name, record, prefix, options, &block)
          options = options ? options.dup : {}
          options[:class] = [ dom_class(record, prefix), options[:class] ].compact
          options[:id]    = dom_id(record, prefix)

          if block_given?
            content_tag(tag_name, capture(record, &block), options)
          else
            content_tag(tag_name, "", options)
          end
        end
    end
  end
end
