
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/output_safety'
require 'active_support/number_helper'

module ActionView
  module Helpers #:nodoc:

    module NumberHelper

      class InvalidNumberError < StandardError
        attr_accessor :number
        def initialize(number)
          @number = number
        end
      end

      def number_to_phone(number, options = {})
        return unless number
        options = options.symbolize_keys

        parse_float(number, true) if options.delete(:raise)
        ERB::Util.html_escape(ActiveSupport::NumberHelper.number_to_phone(number, options))
      end

      def number_to_currency(number, options = {})
        delegate_number_helper_method(:number_to_currency, number, options)
      end

      def number_to_percentage(number, options = {})
        delegate_number_helper_method(:number_to_percentage, number, options)
      end

      def number_with_delimiter(number, options = {})
        delegate_number_helper_method(:number_to_delimited, number, options)
      end

      def number_with_precision(number, options = {})
        delegate_number_helper_method(:number_to_rounded, number, options)
      end

      def number_to_human_size(number, options = {})
        delegate_number_helper_method(:number_to_human_size, number, options)
      end

      def number_to_human(number, options = {})
        delegate_number_helper_method(:number_to_human, number, options)
      end

      private

      def delegate_number_helper_method(method, number, options)
        return unless number
        options = escape_unsafe_options(options.symbolize_keys)

        wrap_with_output_safety_handling(number, options.delete(:raise)) {
          #nodyna <send-1221> <SD MODERATE (change-prone variables)>
          ActiveSupport::NumberHelper.public_send(method, number, options)
        }
      end

      def escape_unsafe_options(options)
        options[:format]          = ERB::Util.html_escape(options[:format]) if options[:format]
        options[:negative_format] = ERB::Util.html_escape(options[:negative_format]) if options[:negative_format]
        options[:separator]       = ERB::Util.html_escape(options[:separator]) if options[:separator]
        options[:delimiter]       = ERB::Util.html_escape(options[:delimiter]) if options[:delimiter]
        options[:unit]            = ERB::Util.html_escape(options[:unit]) if options[:unit] && !options[:unit].html_safe?
        options[:units]           = escape_units(options[:units]) if options[:units] && Hash === options[:units]
        options
      end

      def escape_units(units)
        Hash[units.map do |k, v|
          [k, ERB::Util.html_escape(v)]
        end]
      end

      def wrap_with_output_safety_handling(number, raise_on_invalid, &block)
        valid_float = valid_float?(number)
        raise InvalidNumberError, number if raise_on_invalid && !valid_float

        formatted_number = yield

        if valid_float || number.html_safe?
          formatted_number.html_safe
        else
          formatted_number
        end
      end

      def valid_float?(number)
        !parse_float(number, false).nil?
      end

      def parse_float(number, raise_error)
        Float(number)
      rescue ArgumentError, TypeError
        raise InvalidNumberError, number if raise_error
      end
    end
  end
end
