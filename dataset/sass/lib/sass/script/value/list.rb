module Sass::Script::Value
  class List < Base
    attr_reader :value
    alias_method :to_a, :value

    attr_reader :separator

    def initialize(value, separator)
      super(value)
      @separator = separator
    end

    def options=(options)
      super
      value.each {|v| v.options = options}
    end

    def eq(other)
      Sass::Script::Value::Bool.new(
        other.is_a?(List) && value == other.value &&
        separator == other.separator)
    end

    def hash
      @hash ||= [value, separator].hash
    end

    def to_s(opts = {})
      raise Sass::SyntaxError.new("() isn't a valid CSS value.") if value.empty?
      value.
        reject {|e| e.is_a?(Null) || e.is_a?(List) && e.value.empty?}.
        map {|e| e.to_s(opts)}.join(sep_str)
    end

    def to_sass(opts = {})
      return "()" if value.empty?
      members = value.map do |v|
        if element_needs_parens?(v)
          "(#{v.to_sass(opts)})"
        else
          v.to_sass(opts)
        end
      end
      return "(#{members.first},)" if members.length == 1 && separator == :comma
      members.join(sep_str(nil))
    end

    def to_h
      return Sass::Util.ordered_hash if value.empty?
      super
    end

    def inspect
      "(#{value.map {|e| e.inspect}.join(sep_str(nil))})"
    end

    def self.assert_valid_index(list, n)
      if !n.int? || n.to_i == 0
        raise ArgumentError.new("List index #{n} must be a non-zero integer")
      elsif list.to_a.size == 0
        raise ArgumentError.new("List index is #{n} but list has no items")
      elsif n.to_i.abs > (size = list.to_a.size)
        raise ArgumentError.new(
          "List index is #{n} but list is only #{size} item#{'s' if size != 1} long")
      end
    end

    private

    def element_needs_parens?(element)
      if element.is_a?(List)
        return false if element.value.empty?
        precedence = Sass::Script::Parser.precedence_of(separator)
        return Sass::Script::Parser.precedence_of(element.separator) <= precedence
      end

      return false unless separator == :space
      return false unless element.is_a?(Sass::Script::Tree::UnaryOperation)
      element.operator == :minus || element.operator == :plus
    end

    def sep_str(opts = options)
      return ' ' if separator == :space
      return ',' if opts && opts[:style] == :compressed
      ', '
    end
  end
end
