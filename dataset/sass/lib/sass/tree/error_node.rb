module Sass
  module Tree
    class ErrorNode < Node
      attr_accessor :expr

      def initialize(expr)
        @expr = expr
        super()
      end
    end
  end
end
