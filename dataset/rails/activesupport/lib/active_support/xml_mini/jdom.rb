raise "JRuby is required to use the JDOM backend for XmlMini" unless RUBY_PLATFORM =~ /java/

require 'jruby'
include Java

require 'active_support/core_ext/object/blank'

java_import javax.xml.parsers.DocumentBuilder unless defined? DocumentBuilder
java_import javax.xml.parsers.DocumentBuilderFactory unless defined? DocumentBuilderFactory
java_import java.io.StringReader unless defined? StringReader
java_import org.xml.sax.InputSource unless defined? InputSource
java_import org.xml.sax.Attributes unless defined? Attributes
java_import org.w3c.dom.Node unless defined? Node

module ActiveSupport
  module XmlMini_JDOM #:nodoc:
    extend self

    CONTENT_KEY = '__content__'.freeze

    NODE_TYPE_NAMES = %w{ATTRIBUTE_NODE CDATA_SECTION_NODE COMMENT_NODE DOCUMENT_FRAGMENT_NODE
    DOCUMENT_NODE DOCUMENT_TYPE_NODE ELEMENT_NODE ENTITY_NODE ENTITY_REFERENCE_NODE NOTATION_NODE
    PROCESSING_INSTRUCTION_NODE TEXT_NODE}

    node_type_map = {}
    #nodyna <send-1022> <SD MODERATE (array)>
    NODE_TYPE_NAMES.each { |type| node_type_map[Node.send(type)] = type }

    def parse(data)
      if data.respond_to?(:read)
        data = data.read
      end

      if data.blank?
        {}
      else
        @dbf = DocumentBuilderFactory.new_instance
        @dbf.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
        @dbf.setFeature("http://xml.org/sax/features/external-general-entities", false)
        @dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
        @dbf.setFeature(javax.xml.XMLConstants::FEATURE_SECURE_PROCESSING, true)
        xml_string_reader = StringReader.new(data)
        xml_input_source = InputSource.new(xml_string_reader)
        doc = @dbf.new_document_builder.parse(xml_input_source)
        merge_element!({CONTENT_KEY => ''}, doc.document_element, XmlMini.depth)
      end
    end

    private

    def merge_element!(hash, element, depth)
      raise 'Document too deep!' if depth == 0
      delete_empty(hash)
      merge!(hash, element.tag_name, collapse(element, depth))
    end

    def delete_empty(hash)
      hash.delete(CONTENT_KEY) if hash[CONTENT_KEY] == ''
    end

    def collapse(element, depth)
      hash = get_attributes(element)

      child_nodes = element.child_nodes
      if child_nodes.length > 0
        (0...child_nodes.length).each do |i|
          child = child_nodes.item(i)
          merge_element!(hash, child, depth - 1) unless child.node_type == Node.TEXT_NODE
        end
        merge_texts!(hash, element) unless empty_content?(element)
        hash
      else
        merge_texts!(hash, element)
      end
    end

    def merge_texts!(hash, element)
      delete_empty(hash)
      text_children = texts(element)
      if text_children.join.empty?
        hash
      else
        merge!(hash, CONTENT_KEY, text_children.join)
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
      attribute_hash = {}
      attributes = element.attributes
      (0...attributes.length).each do |i|
         attribute_hash[CONTENT_KEY] ||= ''
         attribute_hash[attributes.item(i).name] =  attributes.item(i).value
       end
      attribute_hash
    end

    def texts(element)
      texts = []
      child_nodes = element.child_nodes
      (0...child_nodes.length).each do |i|
        item = child_nodes.item(i)
        if item.node_type == Node.TEXT_NODE
          texts << item.get_data
        end
      end
      texts
    end

    def empty_content?(element)
      text = ''
      child_nodes = element.child_nodes
      (0...child_nodes.length).each do |i|
        item = child_nodes.item(i)
        if item.node_type == Node.TEXT_NODE
          text << item.get_data.strip
        end
      end
      text.strip.length == 0
    end
  end
end
