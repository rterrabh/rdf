module Sass::Script::Tree
  class Operation < Node
    attr_reader :operand1
    attr_reader :operand2
    attr_reader :operator

    def initialize(operand1, operand2, operator)
      @operand1 = operand1
      @operand2 = operand2
      @operator = operator
      super()
    end

    def inspect
      "(#{@operator.inspect} #{@operand1.inspect} #{@operand2.inspect})"
    end

    def to_sass(opts = {})
      o1 = operand_to_sass @operand1, :left, opts
      o2 = operand_to_sass @operand2, :right, opts
      sep =
        case @operator
        when :comma; ", "
        when :space; " "
        else; " #{Sass::Script::Lexer::OPERATORS_REVERSE[@operator]} "
        end
      "#{o1}#{sep}#{o2}"
    end

    def children
      [@operand1, @operand2]
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3018> <IVS MODERATE (private access)>
      node.instance_variable_set('@operand1', @operand1.deep_copy)
      #nodyna <instance_variable_set-3019> <IVS MODERATE (private access)>
      node.instance_variable_set('@operand2', @operand2.deep_copy)
      node
    end

    protected

    def _perform(environment)
      value1 = @operand1.perform(environment)

      if @operator == :and
        return value1.to_bool ? @operand2.perform(environment) : value1
      elsif @operator == :or
        return value1.to_bool ? value1 : @operand2.perform(environment)
      end

      value2 = @operand2.perform(environment)

      if (value1.is_a?(Sass::Script::Value::Null) || value2.is_a?(Sass::Script::Value::Null)) &&
          @operator != :eq && @operator != :neq
        raise Sass::SyntaxError.new(
          "Invalid null operation: \"#{value1.inspect} #{@operator} #{value2.inspect}\".")
      end

      begin
        #nodyna <send-3020> <SD MODERATE (change-prone variables)>
        result = opts(value1.send(@operator, value2))
      rescue NoMethodError => e
        raise e unless e.name.to_s == @operator.to_s
        raise Sass::SyntaxError.new("Undefined operation: \"#{value1} #{@operator} #{value2}\".")
      end

      if (@operator == :eq || @operator == :neq) && value1.is_a?(Sass::Script::Value::Number) &&
         value2.is_a?(Sass::Script::Value::Number) && value1.unitless? != value2.unitless? &&
         result == (if @operator == :eq
                      Sass::Script::Value::Bool::TRUE
                    else
                      Sass::Script::Value::Bool::FALSE
                    end)

        operation = "#{value1} #{@operator == :eq ? '==' : '!='} #{value2}"
        future_value = @operator == :neq
        Sass::Util.sass_warn <<WARNING
DEPRECATION WARNING on line #{line}#{" of #{filename}" if filename}:
The result of `#{operation}` will be `#{future_value}` in future releases of Sass.
Unitless numbers will no longer be equal to the same numbers with units.
WARNING
      end

      result
    end

    private

    def operand_to_sass(op, side, opts)
      return "(#{op.to_sass(opts)})" if op.is_a?(Sass::Script::Tree::ListLiteral)
      return op.to_sass(opts) unless op.is_a?(Operation)

      pred = Sass::Script::Parser.precedence_of(@operator)
      sub_pred = Sass::Script::Parser.precedence_of(op.operator)
      assoc = Sass::Script::Parser.associative?(@operator)
      return "(#{op.to_sass(opts)})" if sub_pred < pred ||
        (side == :right && sub_pred == pred && !assoc)
      op.to_sass(opts)
    end
  end
end
