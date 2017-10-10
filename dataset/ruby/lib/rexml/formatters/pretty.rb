require 'rexml/formatters/default'

module REXML
  module Formatters
    class Pretty < Default

      attr_accessor :compact
      attr_accessor :width

      def initialize( indentation=2, ie_hack=false )
        @indentation = indentation
        @level = 0
        @ie_hack = ie_hack
        @width = 80
        @compact = false
      end

      protected
      def write_element(node, output)
        output << ' '*@level
        output << "<#{node.expanded_name}"

        node.attributes.each_attribute do |attr|
          output << " "
          attr.write( output )
        end unless node.attributes.empty?

        if node.children.empty?
          if @ie_hack
            output << " "
          end
          output << "/"
        else
          output << ">"
          skip = false
          if compact
            if node.children.inject(true) {|s,c| s & c.kind_of?(Text)}
              string = ""
              old_level = @level
              @level = 0
              node.children.each { |child| write( child, string ) }
              @level = old_level
              if string.length < @width
                output << string
                skip = true
              end
            end
          end
          unless skip
            output << "\n"
            @level += @indentation
            node.children.each { |child|
              next if child.kind_of?(Text) and child.to_s.strip.length == 0
              write( child, output )
              output << "\n"
            }
            @level -= @indentation
            output << ' '*@level
          end
          output << "</#{node.expanded_name}"
        end
        output << ">"
      end

      def write_text( node, output )
        s = node.to_s()
        s.gsub!(/\s/,' ')
        s.squeeze!(" ")
        s = wrap(s, @width - @level)
        s = indent_text(s, @level, " ", true)
        output << (' '*@level + s)
      end

      def write_comment( node, output)
        output << ' ' * @level
        super
      end

      def write_cdata( node, output)
        output << ' ' * @level
        super
      end

      def write_document( node, output )
        node.children.each { |child|
          next if child == node.children[-1] and child.instance_of?(Text)
          unless child == node.children[0] or child.instance_of?(Text) or
            (child == node.children[1] and !node.children[0].writethis)
            output << "\n"
          end
          write( child, output )
        }
      end

      private
      def indent_text(string, level=1, style="\t", indentfirstline=true)
        return string if level < 0
        string.gsub(/\n/, "\n#{style*level}")
      end

      def wrap(string, width)
        parts = []
        while string.length > width and place = string.rindex(' ', width)
          parts << string[0...place]
          string = string[place+1..-1]
        end
        parts << string
        parts.join("\n")
      end

    end
  end
end

