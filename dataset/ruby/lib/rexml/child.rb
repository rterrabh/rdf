require "rexml/node"

module REXML
  class Child
    include Node
    attr_reader :parent         # The Parent of this object

    def initialize( parent = nil )
      @parent = nil
      parent.add( self ) if parent
    end

    def replace_with( child )
      @parent.replace_child( self, child )
      self
    end

    def remove
      unless @parent.nil?
        @parent.delete self
      end
      self
    end

    def parent=( other )
      return @parent if @parent == other
      @parent.delete self if defined? @parent and @parent
      @parent = other
    end

    alias :next_sibling :next_sibling_node
    alias :previous_sibling :previous_sibling_node

    def next_sibling=( other )
      parent.insert_after self, other
    end

    def previous_sibling=(other)
      parent.insert_before self, other
    end

    def document
      return parent.document unless parent.nil?
      nil
    end

    def bytes
      document.encoding

      to_s
    end
  end
end
