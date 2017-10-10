module Sass::Tree
  class CharsetNode < Node
    attr_accessor :name

    def initialize(name)
      @name = name
      super()
    end

    def invisible?
      !Sass::Util.ruby1_8?
    end
  end
end
