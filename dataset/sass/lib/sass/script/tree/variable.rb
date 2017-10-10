module Sass::Script::Tree
  class Variable < Node
    attr_reader :name

    attr_reader :underscored_name

    def initialize(name)
      @name = name
      @underscored_name = name.gsub(/-/, "_")
      super()
    end

    def inspect(opts = {})
      "$#{dasherize(name, opts)}"
    end
    alias_method :to_sass, :inspect

    def children
      []
    end

    def deep_copy
      dup
    end

    protected

    def _perform(environment)
      val = environment.var(name)
      raise Sass::SyntaxError.new("Undefined variable: \"$#{name}\".") unless val
      if val.is_a?(Sass::Script::Value::Number) && val.original
        val = val.dup
        val.original = nil
      end
      val
    end
  end
end
