module Psych
  module Nodes
    class Scalar < Psych::Nodes::Node
      ANY           = 0

      PLAIN         = 1

      SINGLE_QUOTED = 2

      DOUBLE_QUOTED = 3

      LITERAL       = 4

      FOLDED        = 5

      attr_accessor :value

      attr_accessor :anchor

      attr_accessor :tag

      attr_accessor :plain

      attr_accessor :quoted

      attr_accessor :style

      def initialize value, anchor = nil, tag = nil, plain = true, quoted = false, style = ANY
        @value  = value
        @anchor = anchor
        @tag    = tag
        @plain  = plain
        @quoted = quoted
        @style  = style
      end
    end
  end
end
