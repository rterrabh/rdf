module ActionView
  module Helpers
    module CsrfHelper
      def csrf_meta_tags
        if protect_against_forgery?
          [
            tag('meta', :name => 'csrf-param', :content => request_forgery_protection_token),
            tag('meta', :name => 'csrf-token', :content => form_authenticity_token)
          ].join("\n").html_safe
        end
      end

      alias csrf_meta_tag csrf_meta_tags
    end
  end
end
