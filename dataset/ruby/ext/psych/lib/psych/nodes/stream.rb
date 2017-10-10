module Psych
  module Nodes
    class Stream < Psych::Nodes::Node


      ANY     = Psych::Parser::ANY

      UTF8    = Psych::Parser::UTF8

      UTF16LE = Psych::Parser::UTF16LE

      UTF16BE = Psych::Parser::UTF16BE

      attr_accessor :encoding

      def initialize encoding = UTF8
        super()
        @encoding = encoding
      end
    end
  end
end
