module Sass::Tree::Visitors
  class Base
    def self.visit(root)
      #nodyna <send-2989> <SD EASY (private access)>
      new.send(:visit, root)
    end

    protected

    def visit(node)
      if respond_to?(node.class.visit_method, true)
        #nodyna <send-2990> <SD COMPLEX (change-prone variables)>
        send(node.class.visit_method, node) {visit_children(node)}
      else
        visit_children(node)
      end
    end

    def visit_children(parent)
      parent.children.map {|c| visit(c)}
    end

    def self.node_name(node)
      Sass::Util.deprecated(self, "Call node.class.node_name instead.")
      node.class.node_name
    end

    def visit_if(node)
      yield
      visit(node.else) if node.else
      node
    end
  end
end
