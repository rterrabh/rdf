module Psych
  module Nodes
    class Sequence < Psych::Nodes::Node
      ANY   = 0

      BLOCK = 1

      FLOW  = 2

      attr_accessor :anchor

      attr_accessor :tag

      attr_accessor :implicit

      attr_accessor :style

      def initialize anchor = nil, tag = nil, implicit = true, style = BLOCK
        super()
        @anchor   = anchor
        @tag      = tag
        @implicit = implicit
        @style    = style
      end
    end
  end
end
