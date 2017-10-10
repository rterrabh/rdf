require 'active_support/core_ext/string/output_safety'

module ActionView #:nodoc:
  module Helpers #:nodoc:
    module OutputSafetyHelper
      def raw(stringish)
        stringish.to_s.html_safe
      end

      def safe_join(array, sep=$,)
        sep = ERB::Util.unwrapped_html_escape(sep)

        array.flatten.map! { |i| ERB::Util.unwrapped_html_escape(i) }.join(sep).html_safe
      end
    end
  end
end
