module Psych
  module Nodes
    class Alias < Psych::Nodes::Node
      attr_accessor :anchor

      def initialize anchor
        @anchor = anchor
      end
    end
  end
end
