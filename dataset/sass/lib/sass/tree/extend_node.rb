require 'sass/tree/node'

module Sass::Tree
  class ExtendNode < Node
    attr_accessor :resolved_selector

    attr_accessor :selector

    attr_accessor :selector_source_range

    def optional?; @optional; end

    def initialize(selector, optional, selector_source_range)
      @selector = selector
      @optional = optional
      @selector_source_range = selector_source_range
      super()
    end
  end
end
