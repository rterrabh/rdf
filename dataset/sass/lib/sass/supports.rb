module Sass::Supports
  class Condition
    def perform(environment); Sass::Util.abstract(self); end

    def to_css; Sass::Util.abstract(self); end

    def to_src(options); Sass::Util.abstract(self); end

    def deep_copy; Sass::Util.abstract(self); end

    def options=(options); Sass::Util.abstract(self); end
  end

  class Operator < Condition
    attr_accessor :left

    attr_accessor :right

    attr_accessor :op

    def initialize(left, right, op)
      @left = left
      @right = right
      @op = op
    end

    def perform(env)
      @left.perform(env)
      @right.perform(env)
    end

    def to_css
      "#{parens @left, @left.to_css} #{op} #{parens @right, @right.to_css}"
    end

    def to_src(options)
      "#{parens @left, @left.to_src(options)} #{op} #{parens @right, @right.to_src(options)}"
    end

    def deep_copy
      copy = dup
      copy.left = @left.deep_copy
      copy.right = @right.deep_copy
      copy
    end

    def options=(options)
      @left.options = options
      @right.options = options
    end

    private

    def parens(condition, str)
      if condition.is_a?(Negation) || (condition.is_a?(Operator) && condition.op != op)
        return "(#{str})"
      else
        return str
      end
    end
  end

  class Negation < Condition
    attr_accessor :condition

    def initialize(condition)
      @condition = condition
    end

    def perform(env)
      @condition.perform(env)
    end

    def to_css
      "not #{parens @condition.to_css}"
    end

    def to_src(options)
      "not #{parens @condition.to_src(options)}"
    end

    def deep_copy
      copy = dup
      copy.condition = condition.deep_copy
      copy
    end

    def options=(options)
      condition.options = options
    end

    private

    def parens(str)
      return "(#{str})" if @condition.is_a?(Negation) || @condition.is_a?(Operator)
      str
    end
  end

  class Declaration < Condition
    attr_accessor :name

    attr_accessor :resolved_name

    attr_accessor :value

    attr_accessor :resolved_value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def perform(env)
      @resolved_name = name.perform(env)
      @resolved_value = value.perform(env)
    end

    def to_css
      "(#{@resolved_name}: #{@resolved_value})"
    end

    def to_src(options)
      "(#{@name.to_sass(options)}: #{@value.to_sass(options)})"
    end

    def deep_copy
      copy = dup
      copy.name = @name.deep_copy
      copy.value = @value.deep_copy
      copy
    end

    def options=(options)
      @name.options = options
      @value.options = options
    end
  end

  class Interpolation < Condition
    attr_accessor :value

    attr_accessor :resolved_value

    def initialize(value)
      @value = value
    end

    def perform(env)
      @resolved_value = value.perform(env).to_s(:quote => :none)
    end

    def to_css
      @resolved_value
    end

    def to_src(options)
      @value.to_sass(options)
    end

    def deep_copy
      copy = dup
      copy.value = @value.deep_copy
      copy
    end

    def options=(options)
      @value.options = options
    end
  end
end
