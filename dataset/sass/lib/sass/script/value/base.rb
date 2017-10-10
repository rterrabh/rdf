module Sass::Script::Value
  class Base
    attr_reader :value

    attr_accessor :source_range

    def initialize(value = nil)
      value.freeze unless value.nil? || value == true || value == false
      @value = value
    end

    attr_writer :options

    def options
      return @options if @options
      raise Sass::SyntaxError.new(<<MSG)
The #options attribute is not set on this #{self.class}.
  This error is probably occurring because #to_s was called
  on this value within a custom Sass function without first
  setting the #options attribute.
MSG
    end

    def eq(other)
      Sass::Script::Value::Bool.new(self.class == other.class && value == other.value)
    end

    def neq(other)
      Sass::Script::Value::Bool.new(!eq(other).to_bool)
    end

    def unary_not
      Sass::Script::Value::Bool.new(!to_bool)
    end

    def single_eq(other)
      Sass::Script::Value::String.new("#{to_s}=#{other.to_s}")
    end

    def plus(other)
      type = other.is_a?(Sass::Script::Value::String) ? other.type : :identifier
      Sass::Script::Value::String.new(to_s(:quote => :none) + other.to_s(:quote => :none), type)
    end

    def minus(other)
      Sass::Script::Value::String.new("#{to_s}-#{other.to_s}")
    end

    def div(other)
      Sass::Script::Value::String.new("#{to_s}/#{other.to_s}")
    end

    def unary_plus
      Sass::Script::Value::String.new("+#{to_s}")
    end

    def unary_minus
      Sass::Script::Value::String.new("-#{to_s}")
    end

    def unary_div
      Sass::Script::Value::String.new("/#{to_s}")
    end

    def hash
      value.hash
    end

    def eql?(other)
      self == other
    end

    def inspect
      value.inspect
    end

    def to_bool
      true
    end

    def ==(other)
      eq(other).to_bool
    end

    def to_i
      raise Sass::SyntaxError.new("#{inspect} is not an integer.")
    end

    def assert_int!; to_i; end

    def separator; nil; end

    def to_a
      [self]
    end

    def to_h
      raise Sass::SyntaxError.new("#{inspect} is not a map.")
    end

    def to_s(opts = {})
      Sass::Util.abstract(self)
    end
    alias_method :to_sass, :to_s

    def null?
      false
    end

    protected

    def _perform(environment)
      self
    end
  end
end
