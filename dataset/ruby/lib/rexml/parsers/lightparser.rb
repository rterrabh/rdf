require 'rexml/parsers/streamparser'
require 'rexml/parsers/baseparser'
require 'rexml/light/node'

module REXML
  module Parsers
    class LightParser
      def initialize stream
        @stream = stream
        @parser = REXML::Parsers::BaseParser.new( stream )
      end

      def add_listener( listener )
        @parser.add_listener( listener )
      end

      def rewind
        @stream.rewind
        @parser.stream = @stream
      end

      def parse
        root = context = [ :document ]
        while true
          event = @parser.pull
          case event[0]
          when :end_document
            break
          when :start_element, :start_doctype
            new_node = event
            context << new_node
            new_node[1,0] = [context]
            context = new_node
          when :end_element, :end_doctype
            context = context[1]
          else
            new_node = event
            context << new_node
            new_node[1,0] = [context]
          end
        end
        root
      end
    end

  end
end
