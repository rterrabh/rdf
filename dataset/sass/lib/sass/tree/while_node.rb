require 'sass/tree/node'

module Sass::Tree
  class WhileNode < Node
    attr_accessor :expr

    def initialize(expr)
      @expr = expr
      super()
    end
  end
end
