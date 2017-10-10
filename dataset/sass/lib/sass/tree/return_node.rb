module Sass
  module Tree
    class ReturnNode < Node
      attr_accessor :expr

      def initialize(expr)
        @expr = expr
        super()
      end
    end
  end
end
