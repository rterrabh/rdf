require 'rexml/parsers/streamparser'
require 'rexml/parsers/baseparser'

module REXML
  module Parsers
    class UltraLightParser
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
        root = context = []
        while true
          event = @parser.pull
          case event[0]
          when :end_document
            break
          when :end_doctype
            context = context[1]
          when :start_element, :start_doctype
            context << event
            event[1,0] = [context]
            context = event
          when :end_element
            context = context[1]
          else
            context << event
          end
        end
        root
      end
    end

  end
end
