require 'active_support/core_ext/big_decimal/conversions'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'active_support/i18n'
require 'active_support/core_ext/class/attribute'

module ActiveSupport
  module NumberHelper
    class NumberConverter # :nodoc:
      class_attribute :namespace

      class_attribute :validate_float

      attr_reader :number, :opts

      DEFAULTS = {
        format: {
          separator: ".",
          delimiter: ",",
          precision: 3,
          significant: false,
          strip_insignificant_zeros: false
        },

        currency: {
          format: {
            format: "%u%n",
            negative_format: "-%u%n",
            unit: "$",
            separator: ".",
            delimiter: ",",
            precision: 2,
            significant: false,
            strip_insignificant_zeros: false
          }
        },

        percentage: {
          format: {
            delimiter: "",
            format: "%n%"
          }
        },

        precision: {
          format: {
            delimiter: ""
          }
        },

        human: {
          format: {
            delimiter: "",
            precision: 3,
            significant: true,
            strip_insignificant_zeros: true
          },
          storage_units: {
            format: "%n %u",
            units: {
              byte: "Bytes",
              kb: "KB",
              mb: "MB",
              gb: "GB",
              tb: "TB"
            }
          },
          decimal_units: {
            format: "%n %u",
            units: {
              unit: "",
              thousand: "Thousand",
              million: "Million",
              billion: "Billion",
              trillion: "Trillion",
              quadrillion: "Quadrillion"
            }
          }
        }
      }

      def self.convert(number, options)
        new(number, options).execute
      end

      def initialize(number, options)
        @number = number
        @opts   = options.symbolize_keys
      end

      def execute
        if !number
          nil
        elsif validate_float? && !valid_float?
          number
        else
          convert
        end
      end

      private

        def options
          @options ||= format_options.merge(opts)
        end

        def format_options #:nodoc:
          default_format_options.merge!(i18n_format_options)
        end

        def default_format_options #:nodoc:
          options = DEFAULTS[:format].dup
          options.merge!(DEFAULTS[namespace][:format]) if namespace
          options
        end

        def i18n_format_options #:nodoc:
          locale = opts[:locale]
          options = I18n.translate(:'number.format', locale: locale, default: {}).dup

          if namespace
            options.merge!(I18n.translate(:"number.#{namespace}.format", locale: locale, default: {}))
          end

          options
        end

        def translate_number_value_with_default(key, i18n_options = {}) #:nodoc:
          I18n.translate(key, { default: default_value(key), scope: :number }.merge!(i18n_options))
        end

        def translate_in_locale(key, i18n_options = {})
          translate_number_value_with_default(key, { locale: options[:locale] }.merge(i18n_options))
        end

        def default_value(key)
          key.split('.').reduce(DEFAULTS) { |defaults, k| defaults[k.to_sym] }
        end

        def valid_float? #:nodoc:
          Float(number)
        rescue ArgumentError, TypeError
          false
        end
    end
  end
end
