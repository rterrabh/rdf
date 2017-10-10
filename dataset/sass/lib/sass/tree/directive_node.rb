module Sass::Tree
  class DirectiveNode < Node
    attr_accessor :value

    attr_accessor :resolved_value

    attr_accessor :tabs

    attr_accessor :group_end

    def initialize(value)
      @value = value
      @tabs = 0
      super()
    end

    def self.resolved(value)
      node = new([value])
      node.resolved_value = value
      node
    end

    def name
      @name ||= value.first.gsub(/ .*$/, '')
    end

    def normalized_name
      @normalized_name ||= name.gsub(/^(@)(?:-[a-zA-Z0-9]+-)?/, '\1').downcase
    end

    def bubbles?
      has_children
    end
  end
end
