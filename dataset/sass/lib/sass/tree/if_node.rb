require 'sass/tree/node'

module Sass::Tree
  class IfNode < Node
    attr_accessor :expr

    attr_accessor :else

    def initialize(expr)
      @expr = expr
      @last_else = self
      super()
    end

    def add_else(node)
      @last_else.else = node
      @last_else = node
    end

    def _dump(f)
      Marshal.dump([expr, self.else, children])
    end

    def self._load(data)
      expr, else_, children = Marshal.load(data)
      node = IfNode.new(expr)
      node.else = else_
      node.children = children
      #nodyna <instance_variable_set-2998> <not yet classified>
      node.instance_variable_set('@last_else',
        #nodyna <instance_variable_get-2999> <not yet classified>
        node.else ? node.else.instance_variable_get('@last_else') : node)
      node
    end
  end
end
