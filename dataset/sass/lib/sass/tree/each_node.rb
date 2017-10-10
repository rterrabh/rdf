require 'sass/tree/node'

module Sass::Tree
  class EachNode < Node
    attr_reader :vars

    attr_accessor :list

    def initialize(vars, list)
      @vars = vars
      @list = list
      super()
    end
  end
end
