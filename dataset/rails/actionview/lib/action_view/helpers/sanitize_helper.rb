require 'active_support/core_ext/object/try'
require 'active_support/deprecation'
require 'rails-html-sanitizer'

module ActionView
  module Helpers
    module SanitizeHelper
      extend ActiveSupport::Concern
      def sanitize(html, options = {})
        self.class.white_list_sanitizer.sanitize(html, options).try(:html_safe)
      end

      def sanitize_css(style)
        self.class.white_list_sanitizer.sanitize_css(style)
      end

      def strip_tags(html)
        self.class.full_sanitizer.sanitize(html, encode_special_chars: false)
      end

      def strip_links(html)
        self.class.link_sanitizer.sanitize(html)
      end

      module ClassMethods #:nodoc:
        attr_writer :full_sanitizer, :link_sanitizer, :white_list_sanitizer

        def sanitizer_vendor
          Rails::Html::Sanitizer
        end

        def sanitized_allowed_tags
          sanitizer_vendor.white_list_sanitizer.allowed_tags
        end

        def sanitized_allowed_attributes
          sanitizer_vendor.white_list_sanitizer.allowed_attributes
        end

        def full_sanitizer
          @full_sanitizer ||= sanitizer_vendor.full_sanitizer.new
        end

        def link_sanitizer
          @link_sanitizer ||= sanitizer_vendor.link_sanitizer.new
        end

        def white_list_sanitizer
          @white_list_sanitizer ||= sanitizer_vendor.white_list_sanitizer.new
        end
      end
    end
  end
end
