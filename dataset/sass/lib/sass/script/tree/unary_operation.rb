module Sass::Script::Tree
  class UnaryOperation < Node
    attr_reader :operator

    attr_reader :operand

    def initialize(operand, operator)
      @operand = operand
      @operator = operator
      super()
    end

    def inspect
      "(#{@operator.inspect} #{@operand.inspect})"
    end

    def to_sass(opts = {})
      operand = @operand.to_sass(opts)
      if @operand.is_a?(Operation) ||
          (@operator == :minus &&
           (operand =~ Sass::SCSS::RX::IDENT) == 0)
        operand = "(#{@operand.to_sass(opts)})"
      end
      op = Sass::Script::Lexer::OPERATORS_REVERSE[@operator]
      op + (op =~ /[a-z]/ ? " " : "") + operand
    end

    def children
      [@operand]
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3016> <IVS MODERATE (private access)>
      node.instance_variable_set('@operand', @operand.deep_copy)
      node
    end

    protected

    def _perform(environment)
      operator = "unary_#{@operator}"
      value = @operand.perform(environment)
      #nodyna <send-3017> <SD MODERATE (change-prone variables)>
      value.send(operator)
    rescue NoMethodError => e
      raise e unless e.name.to_s == operator.to_s
      raise Sass::SyntaxError.new("Undefined unary operation: \"#{@operator} #{value}\".")
    end
  end
end
