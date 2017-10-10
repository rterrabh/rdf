require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/object/blank'
require 'stringio'

module ActiveSupport
  module XmlMini_REXML #:nodoc:
    extend self

    CONTENT_KEY = '__content__'.freeze

    def parse(data)
      if !data.respond_to?(:read)
        data = StringIO.new(data || '')
      end

      char = data.getc
      if char.nil?
        {}
      else
        data.ungetc(char)
        silence_warnings { require 'rexml/document' } unless defined?(REXML::Document)
        doc = REXML::Document.new(data)

        if doc.root
          merge_element!({}, doc.root, XmlMini.depth)
        else
          raise REXML::ParseException,
            "The document #{doc.to_s.inspect} does not have a valid root"
        end
      end
    end

    private
      def merge_element!(hash, element, depth)
        raise REXML::ParseException, "The document is too deep" if depth == 0
        merge!(hash, element.name, collapse(element, depth))
      end

      def collapse(element, depth)
        hash = get_attributes(element)

        if element.has_elements?
          element.each_element {|child| merge_element!(hash, child, depth - 1) }
          merge_texts!(hash, element) unless empty_content?(element)
          hash
        else
          merge_texts!(hash, element)
        end
      end

      def merge_texts!(hash, element)
        unless element.has_text?
          hash
        else
          texts = ''
          element.texts.each { |t| texts << t.value }
          merge!(hash, CONTENT_KEY, texts)
        end
      end

      def merge!(hash, key, value)
        if hash.has_key?(key)
          if hash[key].instance_of?(Array)
            hash[key] << value
          else
            hash[key] = [hash[key], value]
          end
        elsif value.instance_of?(Array)
          hash[key] = [value]
        else
          hash[key] = value
        end
        hash
      end

      def get_attributes(element)
        attributes = {}
        element.attributes.each { |n,v| attributes[n] = v }
        attributes
      end

      def empty_content?(element)
        element.texts.join.blank?
      end
  end
end
