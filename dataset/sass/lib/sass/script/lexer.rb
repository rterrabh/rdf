require 'sass/scss/rx'

module Sass
  module Script
    class Lexer
      include Sass::SCSS::RX

      Token = Struct.new(:type, :value, :source_range, :pos)

      def line
        return @line unless @tok
        @tok.source_range.start_pos.line
      end

      def offset
        return @offset unless @tok
        @tok.source_range.start_pos.offset
      end

      OPERATORS = {
        '+' => :plus,
        '-' => :minus,
        '*' => :times,
        '/' => :div,
        '%' => :mod,
        '=' => :single_eq,
        ':' => :colon,
        '(' => :lparen,
        ')' => :rparen,
        ',' => :comma,
        'and' => :and,
        'or' => :or,
        'not' => :not,
        '==' => :eq,
        '!=' => :neq,
        '>=' => :gte,
        '<=' => :lte,
        '>' => :gt,
        '<' => :lt,
        '#{' => :begin_interpolation,
        '}' => :end_interpolation,
        ';' => :semicolon,
        '{' => :lcurly,
        '...' => :splat,
      }

      OPERATORS_REVERSE = Sass::Util.map_hash(OPERATORS) {|k, v| [v, k]}

      TOKEN_NAMES = Sass::Util.map_hash(OPERATORS_REVERSE) {|k, v| [k, v.inspect]}.merge(
          :const => "variable (e.g. $foo)",
          :ident => "identifier (e.g. middle)")

      OP_NAMES = OPERATORS.keys.sort_by {|o| -o.size}

      IDENT_OP_NAMES = OP_NAMES.select {|k, v| k =~ /^\w+/}

      PARSEABLE_NUMBER = /(?:(\d*\.\d+)|(\d+))(?:[eE]([+-]?\d+))?(#{UNIT})?/

      REGULAR_EXPRESSIONS = {
        :whitespace => /\s+/,
        :comment => COMMENT,
        :single_line_comment => SINGLE_LINE_COMMENT,
        :variable => /(\$)(#{IDENT})/,
        :ident => /(#{IDENT})(\()?/,
        :number => PARSEABLE_NUMBER,
        :unary_minus_number => /-#{PARSEABLE_NUMBER}/,
        :color => HEXCOLOR,
        :id => /##{IDENT}/,
        :selector => /&/,
        :ident_op => /(#{Regexp.union(*IDENT_OP_NAMES.map do |s|
          Regexp.new(Regexp.escape(s) + "(?!#{NMCHAR}|\Z)")
        end)})/,
        :op => /(#{Regexp.union(*OP_NAMES)})/,
      }

      class << self
        private

        def string_re(open, close)
          /#{open}((?:\\.|\#(?!\{)|[^#{close}\\#])*)(#{close}|#\{)/m
        end
      end

      STRING_REGULAR_EXPRESSIONS = {
        :double => {
          false => string_re('"', '"'),
          true => string_re('', '"')
        },
        :single => {
          false => string_re("'", "'"),
          true => string_re('', "'")
        },
        :uri => {
          false => /url\(#{W}(#{URLCHAR}*?)(#{W}\)|#\{)/,
          true => /(#{URLCHAR}*?)(#{W}\)|#\{)/
        },
        :url_prefix => {
          false => /url-prefix\(#{W}(#{URLCHAR}*?)(#{W}\)|#\{)/,
          true => /(#{URLCHAR}*?)(#{W}\)|#\{)/
        },
        :domain => {
          false => /domain\(#{W}(#{URLCHAR}*?)(#{W}\)|#\{)/,
          true => /(#{URLCHAR}*?)(#{W}\)|#\{)/
        }
      }

      def initialize(str, line, offset, options)
        @scanner = str.is_a?(StringScanner) ? str : Sass::Util::MultibyteStringScanner.new(str)
        @line = line
        @offset = offset
        @options = options
        @interpolation_stack = []
        @prev = nil
      end

      def next
        @tok ||= read_token
        @tok, tok = nil, @tok
        @prev = tok
        tok
      end

      def whitespace?(tok = @tok)
        if tok
          @scanner.string[0...tok.pos] =~ /\s\Z/
        else
          @scanner.string[@scanner.pos, 1] =~ /^\s/ ||
            @scanner.string[@scanner.pos - 1, 1] =~ /\s\Z/
        end
      end

      def peek
        @tok ||= read_token
      end

      def unpeek!
        if @tok
          @scanner.pos = @tok.pos
          @line = @tok.source_range.start_pos.line
          @offset = @tok.source_range.start_pos.offset
        end
      end

      def done?
        return if @next_tok
        whitespace unless after_interpolation? && !@interpolation_stack.empty?
        @scanner.eos? && @tok.nil?
      end

      def after_interpolation?
        @prev && @prev.type == :end_interpolation
      end

      def expected!(name)
        unpeek!
        Sass::SCSS::Parser.expected(@scanner, name, @line)
      end

      def str
        old_pos = @tok ? @tok.pos : @scanner.pos
        yield
        new_pos = @tok ? @tok.pos : @scanner.pos
        @scanner.string[old_pos...new_pos]
      end

      private

      def read_token
        if (tok = @next_tok)
          @next_tok = nil
          return tok
        end

        return if done?
        start_pos = source_position
        value = token
        return unless value
        type, val = value
        Token.new(type, val, range(start_pos), @scanner.pos - @scanner.matched_size)
      end

      def whitespace
        nil while scan(REGULAR_EXPRESSIONS[:whitespace]) ||
          scan(REGULAR_EXPRESSIONS[:comment]) ||
          scan(REGULAR_EXPRESSIONS[:single_line_comment])
      end

      def token
        if after_interpolation? && (interp = @interpolation_stack.pop)
          interp_type, interp_value = interp
          if interp_type == :special_fun
            return special_fun_body(interp_value)
          else
            raise "[BUG]: Unknown interp_type #{interp_type}" unless interp_type == :string
            return string(interp_value, true)
          end
        end

        variable || string(:double, false) || string(:single, false) || number || id || color ||
          selector || string(:uri, false) || raw(UNICODERANGE) || special_fun || special_val ||
          ident_op || ident || op
      end

      def variable
        _variable(REGULAR_EXPRESSIONS[:variable])
      end

      def _variable(rx)
        return unless scan(rx)

        [:const, @scanner[2]]
      end

      def ident
        return unless scan(REGULAR_EXPRESSIONS[:ident])
        [@scanner[2] ? :funcall : :ident, @scanner[1]]
      end

      def string(re, open)
        line, offset = @line, @offset
        return unless scan(STRING_REGULAR_EXPRESSIONS[re][open])
        if @scanner[0] =~ /([^\\]|^)\n/
          filename = @options[:filename]
          Sass::Util.sass_warn <<MESSAGE
DEPRECATION WARNING on line #{line}, column #{offset}#{" of #{filename}" if filename}:
Unescaped multiline strings are deprecated and will be removed in a future version of Sass.
To include a newline in a string, use "\\a" or "\\a " as in CSS.
MESSAGE
        end

        if @scanner[2] == '#{' # '
          @interpolation_stack << [:string, re]
          start_pos = Sass::Source::Position.new(@line, @offset - 2)
          @next_tok = Token.new(:string_interpolation, range(start_pos), @scanner.pos - 2)
        end
        str =
          if re == :uri
            url = "#{'url(' unless open}#{@scanner[1]}#{')' unless @scanner[2] == '#{'}"
            Script::Value::String.new(url)
          else
            Script::Value::String.new(Sass::Script::Value::String.value(@scanner[1]), :string)
          end
        [:string, str]
      end

      def number
        if @scanner.peek(1) == '-'
          return if @scanner.pos == 0
          unary_minus_allowed =
            case @scanner.string[@scanner.pos - 1, 1]
            when /\s/; true
            when '/'; @scanner.pos != 1 && @scanner.string[@scanner.pos - 2, 1] == '*'
            else; false
            end

          return unless unary_minus_allowed
          return unless scan(REGULAR_EXPRESSIONS[:unary_minus_number])
          minus = true
        else
          return unless scan(REGULAR_EXPRESSIONS[:number])
          minus = false
        end

        value = (@scanner[1] ? @scanner[1].to_f : @scanner[2].to_i) * (minus ? -1 : 1)
        value *= 10**@scanner[3].to_i if @scanner[3]
        script_number = Script::Value::Number.new(value, Array(@scanner[4]))
        [:number, script_number]
      end

      def id
        return unless scan(REGULAR_EXPRESSIONS[:id])
        if @scanner[0] =~ /^\#[0-9a-fA-F]+$/ && (@scanner[0].length == 4 || @scanner[0].length == 7)
          return [:color, Script::Value::Color.from_hex(@scanner[0])]
        end
        [:ident, @scanner[0]]
      end

      def color
        return unless @scanner.match?(REGULAR_EXPRESSIONS[:color])
        return unless @scanner[0].length == 4 || @scanner[0].length == 7
        script_color = Script::Value::Color.from_hex(scan(REGULAR_EXPRESSIONS[:color]))
        [:color, script_color]
      end

      def selector
        start_pos = source_position
        return unless scan(REGULAR_EXPRESSIONS[:selector])
        script_selector = Script::Tree::Selector.new
        script_selector.source_range = range(start_pos)
        [:selector, script_selector]
      end

      def special_fun
        prefix = scan(/((-[\w-]+-)?(calc|element)|expression|progid:[a-z\.]*)\(/i)
        return unless prefix
        special_fun_body(1, prefix)
      end

      def special_fun_body(parens, prefix = nil)
        str = prefix || ''
        while (scanned = scan(/.*?([()]|\#\{)/m))
          str << scanned
          if scanned[-1] == ?(
            parens += 1
            next
          elsif scanned[-1] == ?)
            parens -= 1
            next unless parens == 0
          else
            raise "[BUG] Unreachable" unless @scanner[1] == '#{' # '
            str.slice!(-2..-1)
            @interpolation_stack << [:special_fun, parens]
            start_pos = Sass::Source::Position.new(@line, @offset - 2)
            @next_tok = Token.new(:string_interpolation, range(start_pos), @scanner.pos - 2)
          end

          return [:special_fun, Sass::Script::Value::String.new(str)]
        end

        scan(/.*/)
        expected!('")"')
      end

      def special_val
        return unless scan(/!important/i)
        [:string, Script::Value::String.new("!important")]
      end

      def ident_op
        op = scan(REGULAR_EXPRESSIONS[:ident_op])
        return unless op
        [OPERATORS[op]]
      end

      def op
        op = scan(REGULAR_EXPRESSIONS[:op])
        return unless op
        name = OPERATORS[op]
        @interpolation_stack << nil if name == :begin_interpolation
        [name]
      end

      def raw(rx)
        val = scan(rx)
        return unless val
        [:raw, val]
      end

      def scan(re)
        str = @scanner.scan(re)
        return unless str
        c = str.count("\n")
        @line += c
        @offset = (c == 0 ? @offset + str.size : str.size - str.rindex("\n"))
        str
      end

      def range(start_pos, end_pos = source_position)
        Sass::Source::Range.new(start_pos, end_pos, @options[:filename], @options[:importer])
      end

      def source_position
        Sass::Source::Position.new(@line, @offset)
      end
    end
  end
end
