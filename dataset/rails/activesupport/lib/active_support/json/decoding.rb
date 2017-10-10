require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'json'

module ActiveSupport
  mattr_accessor :parse_json_times

  module JSON
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[T \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/
    
    class << self
      def decode(json, options = {})
        if options.present?
          raise ArgumentError, "In Rails 4.1, ActiveSupport::JSON.decode no longer " \
            "accepts an options hash for MultiJSON. MultiJSON reached its end of life " \
            "and has been removed."
        end

        data = ::JSON.parse(json, quirks_mode: true)

        if ActiveSupport.parse_json_times
          convert_dates_from(data)
        else
          data
        end
      end

      def parse_error
        ::JSON::ParserError
      end

      private

      def convert_dates_from(data)
        case data
        when nil
          nil
        when DATE_REGEX
          begin
            DateTime.parse(data)
          rescue ArgumentError
            data
          end
        when Array
          data.map! { |d| convert_dates_from(d) }
        when Hash
          data.each do |key, value|
            data[key] = convert_dates_from(value)
          end
        else
          data
        end
      end
    end
  end
end
