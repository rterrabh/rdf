module Sass::Tree
  class KeyframeRuleNode < Node
    attr_accessor :resolved_value

    def initialize(resolved_value)
      @resolved_value = resolved_value
      super()
    end
  end
end
