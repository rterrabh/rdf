require 'sass/tree/node'

module Sass::Tree
  class TraceNode < Node
    attr_reader :name

    def initialize(name)
      @name = name
      self.has_children = true
      super()
    end

    def self.from_node(name, node)
      trace = new(name)
      trace.line = node.line
      trace.filename = node.filename
      trace.options = node.options
      trace
    end
  end
end
