module Psych
  module Nodes
    class Document < Psych::Nodes::Node
      attr_accessor :version

      attr_accessor :tag_directives

      attr_accessor :implicit

      attr_accessor :implicit_end

      def initialize version = [], tag_directives = [], implicit = false
        super()
        @version        = version
        @tag_directives = tag_directives
        @implicit       = implicit
        @implicit_end   = true
      end

      def root
        children.first
      end
    end
  end
end
