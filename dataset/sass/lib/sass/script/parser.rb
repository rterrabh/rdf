require 'sass/script/lexer'

module Sass
  module Script
    class Parser
      def line
        @lexer.line
      end

      def offset
        @lexer.offset
      end

      def initialize(str, line, offset, options = {})
        @options = options
        @lexer = lexer_class.new(str, line, offset, options)
      end

      def parse_interpolated(warn_for_color = false)
        start_pos = Sass::Source::Position.new(line, offset - 2)
        expr = assert_expr :expr
        assert_tok :end_interpolation
        expr = Sass::Script::Tree::Interpolation.new(
          nil, expr, nil, !:wb, !:wa, !:originally_text, warn_for_color)
        expr.options = @options
        node(expr, start_pos)
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse
        expr = assert_expr :expr
        assert_done
        expr.options = @options
        expr
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse_until(tokens)
        @stop_at = tokens
        expr = assert_expr :expr
        assert_done
        expr.options = @options
        expr
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse_mixin_include_arglist
        args, keywords = [], {}
        if try_tok(:lparen)
          args, keywords, splat, kwarg_splat = mixin_arglist
          assert_tok(:rparen)
        end
        assert_done

        args.each {|a| a.options = @options}
        keywords.each {|k, v| v.options = @options}
        splat.options = @options if splat
        kwarg_splat.options = @options if kwarg_splat
        return args, keywords, splat, kwarg_splat
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse_mixin_definition_arglist
        args, splat = defn_arglist!(false)
        assert_done

        args.each do |k, v|
          k.options = @options
          v.options = @options if v
        end
        splat.options = @options if splat
        return args, splat
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse_function_definition_arglist
        args, splat = defn_arglist!(true)
        assert_done

        args.each do |k, v|
          k.options = @options
          v.options = @options if v
        end
        splat.options = @options if splat
        return args, splat
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def parse_string
        unless (peek = @lexer.peek) &&
            (peek.type == :string ||
            (peek.type == :funcall && peek.value.downcase == 'url'))
          lexer.expected!("string")
        end

        expr = assert_expr :funcall
        expr.options = @options
        @lexer.unpeek!
        expr
      rescue Sass::SyntaxError => e
        e.modify_backtrace :line => @lexer.line, :filename => @options[:filename]
        raise e
      end

      def self.parse(*args)
        new(*args).parse
      end

      PRECEDENCE = [
        :comma, :single_eq, :space, :or, :and,
        [:eq, :neq],
        [:gt, :gte, :lt, :lte],
        [:plus, :minus],
        [:times, :div, :mod],
      ]

      ASSOCIATIVE = [:plus, :times]

      class << self
        def precedence_of(op)
          PRECEDENCE.each_with_index do |e, i|
            return i if Array(e).include?(op)
          end
          raise "[BUG] Unknown operator #{op.inspect}"
        end

        def associative?(op)
          ASSOCIATIVE.include?(op)
        end

        private

        def production(name, sub, *ops)
          #nodyna <class_eval-3005> <CE MODERATE (define methods)>
          class_eval <<RUBY, __FILE__, __LINE__ + 1
            def #{name}
              interp = try_ops_after_interp(#{ops.inspect}, #{name.inspect})
              return interp if interp
              return unless e = #{sub}
              while tok = try_toks(#{ops.map {|o| o.inspect}.join(', ')})
                if interp = try_op_before_interp(tok, e)
                  other_interp = try_ops_after_interp(#{ops.inspect}, #{name.inspect}, interp)
                  return interp unless other_interp
                  return other_interp
                end

                e = node(Tree::Operation.new(e, assert_expr(#{sub.inspect}), tok.type),
                         e.source_range.start_pos)
              end
              e
            end
RUBY
        end

        def unary(op, sub)
          #nodyna <class_eval-3006> <CE MODERATE (define methods)>
          class_eval <<RUBY, __FILE__, __LINE__ + 1
            def unary_#{op}
              return #{sub} unless tok = try_tok(:#{op})
              interp = try_op_before_interp(tok)
              return interp if interp
              start_pos = source_position
              node(Tree::UnaryOperation.new(assert_expr(:unary_#{op}), :#{op}), start_pos)
            end
RUBY
        end
      end

      private

      def source_position
        Sass::Source::Position.new(line, offset)
      end

      def range(start_pos, end_pos = source_position)
        Sass::Source::Range.new(start_pos, end_pos, @options[:filename], @options[:importer])
      end

      def lexer_class; Lexer; end

      def map
        start_pos = source_position
        e = interpolation
        return unless e
        return list e, start_pos unless @lexer.peek && @lexer.peek.type == :colon

        pair = map_pair(e)
        map = node(Sass::Script::Tree::MapLiteral.new([pair]), start_pos)
        while try_tok(:comma)
          pair = map_pair
          return map unless pair
          map.pairs << pair
        end
        map
      end

      def map_pair(key = nil)
        return unless key ||= interpolation
        assert_tok :colon
        return key, assert_expr(:interpolation)
      end

      def expr
        start_pos = source_position
        e = interpolation
        return unless e
        list e, start_pos
      end

      def list(first, start_pos)
        return first unless @lexer.peek && @lexer.peek.type == :comma

        list = node(Sass::Script::Tree::ListLiteral.new([first], :comma), start_pos)
        while (tok = try_tok(:comma))
          element_before_interp = list.elements.length == 1 ? list.elements.first : list
          if (interp = try_op_before_interp(tok, element_before_interp))
            other_interp = try_ops_after_interp([:comma], :expr, interp)
            return interp unless other_interp
            return other_interp
          end
          return list unless (e = interpolation)
          list.elements << e
          list.source_range.end_pos = list.elements.last.source_range.end_pos
        end
        list
      end

      production :equals, :interpolation, :single_eq

      def try_op_before_interp(op, prev = nil)
        return unless @lexer.peek && @lexer.peek.type == :begin_interpolation
        wb = @lexer.whitespace?(op)
        str = literal_node(Script::Value::String.new(Lexer::OPERATORS_REVERSE[op.type]),
                           op.source_range)
        interp = node(
          Script::Tree::Interpolation.new(prev, str, nil, wb, !:wa, :originally_text),
          (prev || str).source_range.start_pos)
        interpolation(interp)
      end

      def try_ops_after_interp(ops, name, prev = nil)
        return unless @lexer.after_interpolation?
        op = try_toks(*ops)
        return unless op
        interp = try_op_before_interp(op, prev)
        return interp if interp

        wa = @lexer.whitespace?
        str = literal_node(Script::Value::String.new(Lexer::OPERATORS_REVERSE[op.type]),
                           op.source_range)
        str.line = @lexer.line
        interp = node(
          Script::Tree::Interpolation.new(prev, str, assert_expr(name), !:wb, wa, :originally_text),
          (prev || str).source_range.start_pos)
        interp
      end

      def interpolation(first = space)
        e = first
        while (interp = try_tok(:begin_interpolation))
          wb = @lexer.whitespace?(interp)
          mid = assert_expr :expr
          assert_tok :end_interpolation
          wa = @lexer.whitespace?
          e = node(
            Script::Tree::Interpolation.new(e, mid, space, wb, wa),
            (e || mid).source_range.start_pos)
        end
        e
      end

      def space
        start_pos = source_position
        e = or_expr
        return unless e
        arr = [e]
        while (e = or_expr)
          arr << e
        end
        if arr.size == 1
          arr.first
        else
          node(Sass::Script::Tree::ListLiteral.new(arr, :space), start_pos)
        end
      end

      production :or_expr, :and_expr, :or
      production :and_expr, :eq_or_neq, :and
      production :eq_or_neq, :relational, :eq, :neq
      production :relational, :plus_or_minus, :gt, :gte, :lt, :lte
      production :plus_or_minus, :times_div_or_mod, :plus, :minus
      production :times_div_or_mod, :unary_plus, :times, :div, :mod

      unary :plus, :unary_minus
      unary :minus, :unary_div
      unary :div, :unary_not # For strings, so /foo/bar works
      unary :not, :ident

      def ident
        return funcall unless @lexer.peek && @lexer.peek.type == :ident
        return if @stop_at && @stop_at.include?(@lexer.peek.value)

        name = @lexer.next
        if (color = Sass::Script::Value::Color::COLOR_NAMES[name.value.downcase])
          literal_node(Sass::Script::Value::Color.new(color, name.value), name.source_range)
        elsif name.value == "true"
          literal_node(Sass::Script::Value::Bool.new(true), name.source_range)
        elsif name.value == "false"
          literal_node(Sass::Script::Value::Bool.new(false), name.source_range)
        elsif name.value == "null"
          literal_node(Sass::Script::Value::Null.new, name.source_range)
        else
          literal_node(Sass::Script::Value::String.new(name.value, :identifier), name.source_range)
        end
      end

      def funcall
        tok = try_tok(:funcall)
        return raw unless tok
        args, keywords, splat, kwarg_splat = fn_arglist
        assert_tok(:rparen)
        node(Script::Tree::Funcall.new(tok.value, args, keywords, splat, kwarg_splat),
          tok.source_range.start_pos, source_position)
      end

      def defn_arglist!(must_have_parens)
        if must_have_parens
          assert_tok(:lparen)
        else
          return [], nil unless try_tok(:lparen)
        end
        return [], nil if try_tok(:rparen)

        res = []
        splat = nil
        must_have_default = false
        loop do
          c = assert_tok(:const)
          var = node(Script::Tree::Variable.new(c.value), c.source_range)
          if try_tok(:colon)
            val = assert_expr(:space)
            must_have_default = true
          elsif try_tok(:splat)
            splat = var
            break
          elsif must_have_default
            raise SyntaxError.new(
              "Required argument #{var.inspect} must come before any optional arguments.")
          end
          res << [var, val]
          break unless try_tok(:comma)
        end
        assert_tok(:rparen)
        return res, splat
      end

      def fn_arglist
        arglist(:equals, "function argument")
      end

      def mixin_arglist
        arglist(:interpolation, "mixin argument")
      end

      def arglist(subexpr, description)
        args = []
        keywords = Sass::Util::NormalizedMap.new
        #nodyna <send-3007> <SD MODERATE (change-prone variables)>
        e = send(subexpr)

        return [args, keywords] unless e

        splat = nil
        loop do
          if @lexer.peek && @lexer.peek.type == :colon
            name = e
            @lexer.expected!("comma") unless name.is_a?(Tree::Variable)
            assert_tok(:colon)
            value = assert_expr(subexpr, description)

            if keywords[name.name]
              raise SyntaxError.new("Keyword argument \"#{name.to_sass}\" passed more than once")
            end

            keywords[name.name] = value
          else
            if try_tok(:splat)
              return args, keywords, splat, e if splat
              splat, e = e, nil
            elsif splat
              raise SyntaxError.new("Only keyword arguments may follow variable arguments (...).")
            elsif !keywords.empty?
              raise SyntaxError.new("Positional arguments must come before keyword arguments.")
            end

            args << e if e
          end

          return args, keywords, splat unless try_tok(:comma)
          e = assert_expr(subexpr, description)
        end
      end

      def raw
        tok = try_tok(:raw)
        return special_fun unless tok
        literal_node(Script::Value::String.new(tok.value), tok.source_range)
      end

      def special_fun
        first = try_tok(:special_fun)
        return paren unless first
        str = literal_node(first.value, first.source_range)
        return str unless try_tok(:string_interpolation)
        mid = assert_expr :expr
        assert_tok :end_interpolation
        last = assert_expr(:special_fun)
        node(Tree::Interpolation.new(str, mid, last, false, false),
            first.source_range.start_pos)
      end

      def paren
        return variable unless try_tok(:lparen)
        start_pos = source_position
        e = map
        e.force_division! if e
        end_pos = source_position
        assert_tok(:rparen)
        e || node(Sass::Script::Tree::ListLiteral.new([], nil), start_pos, end_pos)
      end

      def variable
        start_pos = source_position
        c = try_tok(:const)
        return string unless c
        node(Tree::Variable.new(*c.value), start_pos)
      end

      def string
        first = try_tok(:string)
        return number unless first
        str = literal_node(first.value, first.source_range)
        return str unless try_tok(:string_interpolation)
        mid = assert_expr :expr
        assert_tok :end_interpolation
        last = assert_expr(:string)
        node(Tree::StringInterpolation.new(str, mid, last), first.source_range.start_pos)
      end

      def number
        tok = try_tok(:number)
        return selector unless tok
        num = tok.value
        num.original = num.to_s
        literal_node(num, tok.source_range.start_pos)
      end

      def selector
        tok = try_tok(:selector)
        return literal unless tok
        node(tok.value, tok.source_range.start_pos)
      end

      def literal
        t = try_tok(:color)
        return literal_node(t.value, t.source_range) if t
      end


      EXPR_NAMES = {
        :string => "string",
        :default => "expression (e.g. 1px, bold)",
        :mixin_arglist => "mixin argument",
        :fn_arglist => "function argument",
        :splat => "...",
        :special_fun => '")"',
      }

      def assert_expr(name, expected = nil)
        #nodyna <send-3008> <SD MODERATE (change-prone variables)>
        e = send(name)
        return e if e
        @lexer.expected!(expected || EXPR_NAMES[name] || EXPR_NAMES[:default])
      end

      def assert_tok(name)
        t = try_tok(name)
        return t if t
        @lexer.expected!(Lexer::TOKEN_NAMES[name] || name.to_s)
      end

      def assert_toks(*names)
        t = try_toks(*names)
        return t if t
        @lexer.expected!(names.map {|tok| Lexer::TOKEN_NAMES[tok] || tok}.join(" or "))
      end

      def try_tok(name)
        peeked = @lexer.peek
        peeked && name == peeked.type && @lexer.next
      end

      def try_toks(*names)
        peeked = @lexer.peek
        peeked && names.include?(peeked.type) && @lexer.next
      end

      def assert_done
        return if @lexer.done?
        @lexer.expected!(EXPR_NAMES[:default])
      end

      def literal_node(value, source_range_or_start_pos, end_pos = source_position)
        node(Sass::Script::Tree::Literal.new(value), source_range_or_start_pos, end_pos)
      end

      def node(node, source_range_or_start_pos, end_pos = source_position)
        source_range =
          if source_range_or_start_pos.is_a?(Sass::Source::Range)
            source_range_or_start_pos
          else
            range(source_range_or_start_pos, end_pos)
          end

        node.line = source_range.start_pos.line
        node.source_range = source_range
        node.filename = @options[:filename]
        node
      end
    end
  end
end
