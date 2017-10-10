module Sass
  module Tree
    class AtRootNode < Node
      attr_accessor :query

      attr_accessor :resolved_type

      attr_accessor :resolved_value

      attr_accessor :tabs

      attr_accessor :group_end

      def initialize(query = nil)
        super()
        @query = Sass::Util.strip_string_array(Sass::Util.merge_adjacent_strings(query)) if query
        @tabs = 0
      end

      def exclude?(directive)
        if resolved_type == :with
          return false if resolved_value.include?('all')
          !resolved_value.include?(directive)
        else # resolved_type == :without
          return true if resolved_value.include?('all')
          resolved_value.include?(directive)
        end
      end

      def exclude_node?(node)
        return exclude?(node.name.gsub(/^@/, '')) if node.is_a?(Sass::Tree::DirectiveNode)
        return exclude?('keyframes') if node.is_a?(Sass::Tree::KeyframeRuleNode)
        exclude?('rule') && node.is_a?(Sass::Tree::RuleNode)
      end

      def bubbles?
        true
      end
    end
  end
end
