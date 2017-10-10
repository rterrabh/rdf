module Sass::Tree
  class PropNode < Node
    attr_accessor :name

    attr_accessor :resolved_name

    attr_accessor :value

    attr_accessor :resolved_value

    attr_accessor :tabs

    attr_accessor :name_source_range

    attr_accessor :value_source_range

    def initialize(name, value, prop_syntax)
      @name = Sass::Util.strip_string_array(
        Sass::Util.merge_adjacent_strings(name))
      @value = value
      @tabs = 0
      @prop_syntax = prop_syntax
      super()
    end

    def ==(other)
      self.class == other.class && name == other.name && value == other.value && super
    end

    def pseudo_class_selector_message
      if @prop_syntax == :new ||
          !value.is_a?(Sass::Script::Tree::Literal) ||
          !value.value.is_a?(Sass::Script::Value::String) ||
          !value.value.value.empty?
        return ""
      end

      "\nIf #{declaration.dump} should be a selector, use \"\\#{declaration}\" instead."
    end

    def declaration(opts = {:old => @prop_syntax == :old}, fmt = :sass)
      name = self.name.map {|n| n.is_a?(String) ? n : n.to_sass(opts)}.join
      if name[0] == ?:
        raise Sass::SyntaxError.new("The \"#{name}: #{self.class.val_to_sass(value, opts)}\"" +
                                    " hack is not allowed in the Sass indented syntax")
      end

      old = opts[:old] && fmt == :sass
      initial = old ? ':' : ''
      mid = old ? '' : ':'
      "#{initial}#{name}#{mid} #{self.class.val_to_sass(value, opts)}".rstrip
    end

    def invisible?
      resolved_value.empty?
    end

    private

    def check!
      if @options[:property_syntax] && @options[:property_syntax] != @prop_syntax
        raise Sass::SyntaxError.new(
          "Illegal property syntax: can't use #{@prop_syntax} syntax when " +
          ":property_syntax => #{@options[:property_syntax].inspect} is set.")
      end
    end

    class << self
      def val_to_sass(value, opts)
        val_to_sass_comma(value, opts).to_sass(opts)
      end

      private

      def val_to_sass_comma(node, opts)
        return node unless node.is_a?(Sass::Script::Tree::Operation)
        return val_to_sass_concat(node, opts) unless node.operator == :comma

        Sass::Script::Tree::Operation.new(
          val_to_sass_concat(node.operand1, opts),
          val_to_sass_comma(node.operand2, opts),
          node.operator)
      end

      def val_to_sass_concat(node, opts)
        return node unless node.is_a?(Sass::Script::Tree::Operation)
        return val_to_sass_div(node, opts) unless node.operator == :space

        Sass::Script::Tree::Operation.new(
          val_to_sass_div(node.operand1, opts),
          val_to_sass_concat(node.operand2, opts),
          node.operator)
      end

      def val_to_sass_div(node, opts)
        unless node.is_a?(Sass::Script::Tree::Operation) && node.operator == :div &&
            node.operand1.is_a?(Sass::Script::Tree::Literal) &&
            node.operand1.value.is_a?(Sass::Script::Value::Number) &&
            node.operand2.is_a?(Sass::Script::Tree::Literal) &&
            node.operand2.value.is_a?(Sass::Script::Value::Number) &&
            (!node.operand1.value.original || !node.operand2.value.original)
          return node
        end

        Sass::Script::Value::String.new("(#{node.to_sass(opts)})")
      end
    end
  end
end
