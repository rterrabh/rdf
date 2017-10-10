require 'forwardable'

require 'rexml/parseexception'
require 'rexml/parsers/baseparser'
require 'rexml/xmltokens'

module REXML
  module Parsers
    class PullParser
      include XMLTokens
      extend Forwardable

      def_delegators( :@parser, :has_next? )
      def_delegators( :@parser, :entity )
      def_delegators( :@parser, :empty? )
      def_delegators( :@parser, :source )

      def initialize stream
        @entities = {}
        @listeners = nil
        @parser = BaseParser.new( stream )
        @my_stack = []
      end

      def add_listener( listener )
        @listeners = [] unless @listeners
        @listeners << listener
      end

      def each
        while has_next?
          yield self.pull
        end
      end

      def peek depth=0
        if @my_stack.length <= depth
          (depth - @my_stack.length + 1).times {
            e = PullEvent.new(@parser.pull)
            @my_stack.push(e)
          }
        end
        @my_stack[depth]
      end

      def pull
        return @my_stack.shift if @my_stack.length > 0

        event = @parser.pull
        case event[0]
        when :entitydecl
          @entities[ event[1] ] =
            event[2] unless event[2] =~ /PUBLIC|SYSTEM/
        when :text
          unnormalized = @parser.unnormalize( event[1], @entities )
          event << unnormalized
        end
        PullEvent.new( event )
      end

      def unshift token
        @my_stack.unshift token
      end
    end

    class PullEvent
      def initialize(arg)
        @contents = arg
      end

      def []( start, endd=nil)
        if start.kind_of? Range
          @contents.slice( start.begin+1 .. start.end )
        elsif start.kind_of? Numeric
          if endd.nil?
            @contents.slice( start+1 )
          else
            @contents.slice( start+1, endd )
          end
        else
          raise "Illegal argument #{start.inspect} (#{start.class})"
        end
      end

      def event_type
        @contents[0]
      end

      def start_element?
        @contents[0] == :start_element
      end

      def end_element?
        @contents[0] == :end_element
      end

      def text?
        @contents[0] == :text
      end

      def instruction?
        @contents[0] == :processing_instruction
      end

      def comment?
        @contents[0] == :comment
      end

      def doctype?
        @contents[0] == :start_doctype
      end

      def attlistdecl?
        @contents[0] == :attlistdecl
      end

      def elementdecl?
        @contents[0] == :elementdecl
      end

      def entitydecl?
        @contents[0] == :entitydecl
      end

      def notationdecl?
        @contents[0] == :notationdecl
      end

      def entity?
        @contents[0] == :entity
      end

      def cdata?
        @contents[0] == :cdata
      end

      def xmldecl?
        @contents[0] == :xmldecl
      end

      def error?
        @contents[0] == :error
      end

      def inspect
        @contents[0].to_s + ": " + @contents[1..-1].inspect
      end
    end
  end
end
