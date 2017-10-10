module Sass
  module Tree
    class Node
      include Enumerable

      def self.inherited(base)
        node_name = base.name.gsub(/.*::(.*?)Node$/, '\\1').downcase
        #nodyna <instance_eval-2997> <IEV COMPLEX (method definition)>
        base.instance_eval <<-METHODS
          def node_name
            :#{node_name}
          end

          def visit_method
            :visit_#{node_name}
          end

          def invalid_child_method_name
            :"invalid_#{node_name}_child?"
          end

          def invalid_parent_method_name
            :"invalid_#{node_name}_parent?"
          end
        METHODS
      end

      attr_reader :children

      attr_accessor :has_children

      attr_accessor :line

      attr_accessor :source_range

      attr_writer :filename

      attr_reader :options

      def initialize
        @children = []
      end

      def options=(options)
        Sass::Tree::Visitors::SetOptions.visit(self, options)
      end

      def children=(children)
        self.has_children ||= !children.empty?
        @children = children
      end

      def filename
        @filename || (@options && @options[:filename])
      end

      def <<(child)
        return if child.nil?
        if child.is_a?(Array)
          child.each {|c| self << c}
        else
          self.has_children = true
          @children << child
        end
      end

      def ==(other)
        self.class == other.class && other.children == children
      end

      def invisible?; false; end

      def style
        @options[:style]
      end

      def css
        Sass::Tree::Visitors::ToCss.new.visit(self)
      end

      def css_with_sourcemap
        visitor = Sass::Tree::Visitors::ToCss.new(:build_source_mapping)
        result = visitor.visit(self)
        return result, visitor.source_mapping
      end

      def inspect
        return self.class.to_s unless has_children
        "(#{self.class} #{children.map {|c| c.inspect}.join(' ')})"
      end

      def each
        yield self
        children.each {|c| c.each {|n| yield n}}
      end

      def to_sass(options = {})
        Sass::Tree::Visitors::Convert.visit(self, options, :sass)
      end

      def to_scss(options = {})
        Sass::Tree::Visitors::Convert.visit(self, options, :scss)
      end

      def deep_copy
        Sass::Tree::Visitors::DeepCopy.visit(self)
      end

      def bubbles?
        false
      end

      protected

      def balance(*args)
        res = Sass::Shared.balance(*args)
        return res if res
        raise Sass::SyntaxError.new("Unbalanced brackets.", :line => line)
      end
    end
  end
end
