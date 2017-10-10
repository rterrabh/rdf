require 'sass/tree/node'

module Sass::Tree
  class MixinNode < Node
    attr_reader :name

    attr_accessor :args

    attr_accessor :keywords

    attr_accessor :splat

    attr_accessor :kwarg_splat

    def initialize(name, args, keywords, splat, kwarg_splat)
      @name = name
      @args = args
      @keywords = keywords
      @splat = splat
      @kwarg_splat = kwarg_splat
      super()
    end
  end
end
