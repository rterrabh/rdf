require 'active_support/xml_mini'
require 'active_support/time'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/string/inflections'

class Hash
  def to_xml(options = {})
    require 'active_support/builder' unless defined?(Builder)

    options = options.dup
    options[:indent]  ||= 2
    options[:root]    ||= 'hash'
    options[:builder] ||= Builder::XmlMarkup.new(indent: options[:indent])

    builder = options[:builder]
    builder.instruct! unless options.delete(:skip_instruct)

    root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)

    builder.tag!(root) do
      each { |key, value| ActiveSupport::XmlMini.to_tag(key, value, options) }
      yield builder if block_given?
    end
  end

  class << self
    def from_xml(xml, disallowed_types = nil)
      ActiveSupport::XMLConverter.new(xml, disallowed_types).to_h
    end

    def from_trusted_xml(xml)
      from_xml xml, []
    end
  end
end

module ActiveSupport
  class XMLConverter # :nodoc:
    class DisallowedType < StandardError
      def initialize(type)
        super "Disallowed type attribute: #{type.inspect}"
      end
    end

    DISALLOWED_TYPES = %w(symbol yaml)

    def initialize(xml, disallowed_types = nil)
      @xml = normalize_keys(XmlMini.parse(xml))
      @disallowed_types = disallowed_types || DISALLOWED_TYPES
    end

    def to_h
      deep_to_h(@xml)
    end

    private
      def normalize_keys(params)
        case params
          when Hash
            Hash[params.map { |k,v| [k.to_s.tr('-', '_'), normalize_keys(v)] } ]
          when Array
            params.map { |v| normalize_keys(v) }
          else
            params
        end
      end

      def deep_to_h(value)
        case value
          when Hash
            process_hash(value)
          when Array
            process_array(value)
          when String
            value
          else
            raise "can't typecast #{value.class.name} - #{value.inspect}"
        end
      end

      def process_hash(value)
        if value.include?('type') && !value['type'].is_a?(Hash) && @disallowed_types.include?(value['type'])
          raise DisallowedType, value['type']
        end

        if become_array?(value)
          _, entries = Array.wrap(value.detect { |k,v| not v.is_a?(String) })
          if entries.nil? || value['__content__'].try(:empty?)
            []
          else
            case entries
            when Array
              entries.collect { |v| deep_to_h(v) }
            when Hash
              [deep_to_h(entries)]
            else
              raise "can't typecast #{entries.inspect}"
            end
          end
        elsif become_content?(value)
          process_content(value)

        elsif become_empty_string?(value)
          ''
        elsif become_hash?(value)
          xml_value = Hash[value.map { |k,v| [k, deep_to_h(v)] }]

          xml_value['file'].is_a?(StringIO) ? xml_value['file'] : xml_value
        end
      end

      def become_content?(value)
        value['type'] == 'file' || (value['__content__'] && (value.keys.size == 1 || value['__content__'].present?))
      end

      def become_array?(value)
        value['type'] == 'array'
      end

      def become_empty_string?(value)
        value['type'] == 'string' && value['nil'] != 'true'
      end

      def become_hash?(value)
        !nothing?(value) && !garbage?(value)
      end

      def nothing?(value)
        value.blank? || value['nil'] == 'true'
      end

      def garbage?(value)
        value['type'] && !value['type'].is_a?(::Hash) && value.size == 1
      end

      def process_content(value)
        content = value['__content__']
        if parser = ActiveSupport::XmlMini::PARSING[value['type']]
          parser.arity == 1 ? parser.call(content) : parser.call(content, value)
        else
          content
        end
      end

      def process_array(value)
        value.map! { |i| deep_to_h(i) }
        value.length > 1 ? value : value.first
      end

  end
end
