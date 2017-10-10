module Sass
  module Tree
    class VariableNode < Node
      attr_reader :name

      attr_accessor :expr

      attr_reader :guarded

      attr_reader :global

      def initialize(name, expr, guarded, global)
        @name = name
        @expr = expr
        @guarded = guarded
        @global = global
        super()
      end
    end
  end
end
