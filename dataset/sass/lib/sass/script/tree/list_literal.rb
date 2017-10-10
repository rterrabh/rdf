module Sass::Script::Tree
  class ListLiteral < Node
    attr_reader :elements

    attr_reader :separator

    def initialize(elements, separator)
      @elements = elements
      @separator = separator
    end

    def children; elements; end

    def to_sass(opts = {})
      return "()" if elements.empty?
      members = elements.map do |v|
        if element_needs_parens?(v)
          "(#{v.to_sass(opts)})"
        else
          v.to_sass(opts)
        end
      end

      return "(#{members.first},)" if separator == :comma && members.length == 1

      members.join(sep_str(nil))
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3009> <not yet classified>
      node.instance_variable_set('@elements', elements.map {|e| e.deep_copy})
      node
    end

    def inspect
      "(#{elements.map {|e| e.inspect}.join(separator == :space ? ' ' : ', ')})"
    end

    def force_division!
    end

    protected

    def _perform(environment)
      list = Sass::Script::Value::List.new(
        elements.map {|e| e.perform(environment)},
        separator)
      list.source_range = source_range
      list.options = options
      list
    end

    private

    def element_needs_parens?(element)
      if element.is_a?(ListLiteral)
        return Sass::Script::Parser.precedence_of(element.separator) <=
               Sass::Script::Parser.precedence_of(separator)
      end

      return false unless separator == :space

      if element.is_a?(UnaryOperation)
        return element.operator == :minus || element.operator == :plus
      end

      return false unless element.is_a?(Operation)
      return true unless element.operator == :div
      !(is_literal_number?(element.operand1) && is_literal_number?(element.operand2))
    end

    def is_literal_number?(value)
      value.is_a?(Literal) &&
        value.value.is_a?((Sass::Script::Value::Number)) &&
        !value.value.original.nil?
    end

    def sep_str(opts = options)
      return ' ' if separator == :space
      return ',' if opts && opts[:style] == :compressed
      ', '
    end
  end
end
