require "rexml/child"

module REXML
  class Parent < Child
    include Enumerable

    def initialize parent=nil
      super(parent)
      @children = []
    end

    def add( object )
      object.parent = self
      @children << object
      object
    end

    alias :push :add
    alias :<< :push

    def unshift( object )
      object.parent = self
      @children.unshift object
    end

    def delete( object )
      found = false
      @children.delete_if {|c| c.equal?(object) and found = true }
      object.parent = nil if found
      found ? object : nil
    end

    def each(&block)
      @children.each(&block)
    end

    def delete_if( &block )
      @children.delete_if(&block)
    end

    def delete_at( index )
      @children.delete_at index
    end

    def each_index( &block )
      @children.each_index(&block)
    end

    def []( index )
      @children[index]
    end

    alias :each_child :each



    def []=( *args )
      args[-1].parent = self
      @children[*args[0..-2]] = args[-1]
    end

    def insert_before( child1, child2 )
      if child1.kind_of? String
        child1 = XPath.first( self, child1 )
        child1.parent.insert_before child1, child2
      else
        ind = index(child1)
        child2.parent.delete(child2) if child2.parent
        @children[ind,0] = child2
        child2.parent = self
      end
      self
    end

    def insert_after( child1, child2 )
      if child1.kind_of? String
        child1 = XPath.first( self, child1 )
        child1.parent.insert_after child1, child2
      else
        ind = index(child1)+1
        child2.parent.delete(child2) if child2.parent
        @children[ind,0] = child2
        child2.parent = self
      end
      self
    end

    def to_a
      @children.dup
    end

    def index( child )
      count = -1
      @children.find { |i| count += 1 ; i.hash == child.hash }
      count
    end

    def size
      @children.size
    end

    alias :length :size

    def replace_child( to_replace, replacement )
      @children.map! {|c| c.equal?( to_replace ) ? replacement : c }
      to_replace.parent = nil
      replacement.parent = self
    end

    def deep_clone
      cl = clone()
      each do |child|
        if child.kind_of? Parent
          cl << child.deep_clone
        else
          cl << child.clone
        end
      end
      cl
    end

    alias :children :to_a

    def parent?
      true
    end
  end
end
