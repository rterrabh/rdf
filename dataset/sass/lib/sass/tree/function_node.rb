module Sass
  module Tree
    class FunctionNode < Node
      attr_reader :name

      attr_accessor :args

      attr_accessor :splat

      def normalized_name
        @normalized_name ||= name.gsub(/^(?:-[a-zA-Z0-9]+-)?/, '\1')
      end

      def initialize(name, args, splat)
        @name = name
        @args = args
        @splat = splat
        super()

        if %w[and or not].include?(name)
          raise Sass::SyntaxError.new("Invalid function name \"#{name}\".")
        end
      end
    end
  end
end
