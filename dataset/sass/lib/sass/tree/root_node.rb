module Sass
  module Tree
    class RootNode < Node
      attr_reader :template

      def initialize(template)
        super()
        @template = template
      end

      def render
        css_tree.css
      end

      def render_with_sourcemap
        css_tree.css_with_sourcemap
      end

      private

      def css_tree
        Visitors::CheckNesting.visit(self)
        result = Visitors::Perform.visit(self)
        Visitors::CheckNesting.visit(result) # Check again to validate mixins
        result, extends = Visitors::Cssize.visit(result)
        Visitors::Extend.visit(result, extends)
        result
      end
    end
  end
end
