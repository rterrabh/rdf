module Sass::Script::Tree
  class Literal < Node
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def children; []; end

    def to_sass(opts = {}); value.to_sass(opts); end

    def deep_copy; dup; end

    def options=(options)
      value.options = options
    end

    def inspect
      value.inspect
    end

    def force_division!
      value.original = nil if value.is_a?(Sass::Script::Value::Number)
    end

    protected

    def _perform(environment)
      value.source_range = source_range
      value
    end
  end
end
