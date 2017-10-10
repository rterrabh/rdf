require 'rexml/formatters/pretty'

module REXML
  module Formatters
    class Transitive < Default
      def initialize( indentation=2, ie_hack=false )
        @indentation = indentation
        @level = 0
        @ie_hack = ie_hack
      end

      protected
      def write_element( node, output )
        output << "<#{node.expanded_name}"

        node.attributes.each_attribute do |attr|
          output << " "
          attr.write( output )
        end unless node.attributes.empty?

        output << "\n"
        output << ' '*@level
        if node.children.empty?
          output << " " if @ie_hack
          output << "/"
        else
          output << ">"
          @level += @indentation
          node.children.each { |child|
            write( child, output )
          }
          @level -= @indentation
          output << "</#{node.expanded_name}"
          output << "\n"
          output << ' '*@level
        end
        output << ">"
      end

      def write_text( node, output )
        output << node.to_s()
      end
    end
  end
end
