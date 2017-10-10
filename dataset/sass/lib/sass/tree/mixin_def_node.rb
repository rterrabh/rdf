module Sass
  module Tree
    class MixinDefNode < Node
      attr_reader :name

      attr_accessor :args

      attr_accessor :splat

      attr_accessor :has_content

      def initialize(name, args, splat)
        @name = name
        @args = args
        @splat = splat
        super()
      end
    end
  end
end
