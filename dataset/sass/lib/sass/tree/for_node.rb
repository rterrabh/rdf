require 'sass/tree/node'

module Sass::Tree
  class ForNode < Node
    attr_reader :var

    attr_accessor :from

    attr_accessor :to

    attr_reader :exclusive

    def initialize(var, from, to, exclusive)
      @var = var
      @from = from
      @to = to
      @exclusive = exclusive
      super()
    end
  end
end
