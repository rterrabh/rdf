module Capybara
  module Node

    class Simple
      include Capybara::Node::Finders
      include Capybara::Node::Matchers
      include Capybara::Node::DocumentMatchers

      attr_reader :native

      def initialize(native)
        native = Capybara::HTML(native) if native.is_a?(String)
        @native = native
      end

      def text(type=nil)
        native.text
      end

      def [](name)
        attr_name = name.to_s
        if attr_name == 'value'
          value
        elsif 'input' == tag_name and 'checkbox' == native[:type] and 'checked' == attr_name
          native['checked'] == 'checked'
        else
          native[attr_name]
        end
      end

      def tag_name
        native.node_name
      end

      def path
        native.path
      end

      def value
        if tag_name == 'textarea'
          native.content
        elsif tag_name == 'select'
          if native['multiple'] == 'multiple'
            native.xpath(".//option[@selected='selected']").map { |option| option[:value] || option.content  }
          else
            option = native.xpath(".//option[@selected='selected']").first || native.xpath(".//option").first
            option[:value] || option.content if option
          end
        elsif tag_name == 'input' && %w(radio checkbox).include?(native[:type])
          native[:value] || 'on'
        else
          native[:value]
        end
      end

      def visible?(check_ancestors = true)
        if check_ancestors
          native.xpath("./ancestor-or-self::*[contains(@style, 'display:none') or contains(@style, 'display: none') or @hidden or name()='script' or name()='head']").size() == 0
        else
          !(native.has_attribute?('hidden') || (native[:style] =~ /display:\s?none/) || %w(script head).include?(tag_name))
        end
      end

      def checked?
        native[:checked]
      end

      def disabled?
        native[:disabled]
      end

      def selected?
        native[:selected]
      end

      def synchronize(seconds=nil)
        yield # simple nodes don't need to wait
      end

      def allow_reload!
      end

      def title
        if native.respond_to? :title
          native.title
        else
          native.xpath('/html/head/title | /html/title').first.text
        end
      end

      def inspect
        %(#<Capybara::Node::Simple tag="#{tag_name}" path="#{path}">)
      end

      def find_css(css)
        native.css(css)
      end

      def find_xpath(xpath)
        native.xpath(xpath)
      end
    end
  end
end
