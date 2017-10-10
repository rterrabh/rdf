begin
  require 'nokogiri'
rescue LoadError => e
  $stderr.puts "You don't have nokogiri installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end
require 'active_support/core_ext/object/blank'
require 'stringio'

module ActiveSupport
  module XmlMini_Nokogiri #:nodoc:
    extend self

    def parse(data)
      if !data.respond_to?(:read)
        data = StringIO.new(data || '')
      end

      char = data.getc
      if char.nil?
        {}
      else
        data.ungetc(char)
        doc = Nokogiri::XML(data)
        raise doc.errors.first if doc.errors.length > 0
        doc.to_hash
      end
    end

    module Conversions #:nodoc:
      module Document #:nodoc:
        def to_hash
          root.to_hash
        end
      end

      module Node #:nodoc:
        CONTENT_ROOT = '__content__'.freeze

        def to_hash(hash={})
          node_hash = {}

          case hash[name]
            when Array then hash[name] << node_hash
            when Hash  then hash[name] = [hash[name], node_hash]
            when nil   then hash[name] = node_hash
          end

          children.each do |c|
            if c.element?
              c.to_hash(node_hash)
            elsif c.text? || c.cdata?
              node_hash[CONTENT_ROOT] ||= ''
              node_hash[CONTENT_ROOT] << c.content
            end
          end

          if node_hash.length > 1 && node_hash[CONTENT_ROOT].blank?
            node_hash.delete(CONTENT_ROOT)
          end

          attribute_nodes.each { |a| node_hash[a.node_name] = a.value }

          hash
        end
      end
    end

    #nodyna <send-1020> <SD TRIVIAL (public methods)>
    Nokogiri::XML::Document.send(:include, Conversions::Document)
    #nodyna <send-1021> <SD TRIVIAL (public methods)>
    Nokogiri::XML::Node.send(:include, Conversions::Node)
  end
end
