require 'set'

module Sass
  module SCSS
    class Parser
      attr_accessor :offset

      def initialize(str, filename, importer, line = 1, offset = 1)
        @template = str
        @filename = filename
        @importer = importer
        @line = line
        @offset = offset
        @strs = []
      end

      def parse
        init_scanner!
        root = stylesheet
        expected("selector or at-rule") unless root && @scanner.eos?
        root
      end

      def parse_interp_ident
        init_scanner!
        interp_ident
      end

      def parse_media_query_list
        init_scanner!
        ql = media_query_list
        expected("media query list") unless ql && @scanner.eos?
        ql
      end

      def parse_at_root_query
        init_scanner!
        query = at_root_query
        expected("@at-root query list") unless query && @scanner.eos?
        query
      end

      def parse_supports_condition
        init_scanner!
        condition = supports_condition
        expected("supports condition") unless condition && @scanner.eos?
        condition
      end

      private

      include Sass::SCSS::RX

      def source_position
        Sass::Source::Position.new(@line, @offset)
      end

      def range(start_pos, end_pos = source_position)
        Sass::Source::Range.new(start_pos, end_pos, @filename, @importer)
      end

      def init_scanner!
        @scanner =
          if @template.is_a?(StringScanner)
            @template
          else
            Sass::Util::MultibyteStringScanner.new(@template.gsub("\r", ""))
          end
      end

      def stylesheet
        node = node(Sass::Tree::RootNode.new(@scanner.string), source_position)
        block_contents(node, :stylesheet) {s(node)}
      end

      def s(node)
        while tok(S) || tok(CDC) || tok(CDO) || (c = tok(SINGLE_LINE_COMMENT)) || (c = tok(COMMENT))
          next unless c
          process_comment c, node
          c = nil
        end
        true
      end

      def ss
        nil while tok(S) || tok(SINGLE_LINE_COMMENT) || tok(COMMENT)
        true
      end

      def ss_comments(node)
        while tok(S) || (c = tok(SINGLE_LINE_COMMENT)) || (c = tok(COMMENT))
          next unless c
          process_comment c, node
          c = nil
        end

        true
      end

      def whitespace
        return unless tok(S) || tok(SINGLE_LINE_COMMENT) || tok(COMMENT)
        ss
      end

      def process_comment(text, node)
        silent = text =~ %r{\A//}
        loud = !silent && text =~ %r{\A/[/*]!}
        line = @line - text.count("\n")

        if silent
          value = [text.sub(%r{\A\s*//}, '/*').gsub(%r{^\s*//}, ' *') + ' */']
        else
          value = Sass::Engine.parse_interp(
            text, line, @scanner.pos - text.size, :filename => @filename)
          string_before_comment = @scanner.string[0...@scanner.pos - text.length]
          newline_before_comment = string_before_comment.rindex("\n")
          last_line_before_comment =
            if newline_before_comment
              string_before_comment[newline_before_comment + 1..-1]
            else
              string_before_comment
            end
          value.unshift(last_line_before_comment.gsub(/[^\s]/, ' '))
        end

        type = if silent
                 :silent
               elsif loud
                 :loud
               else
                 :normal
               end
        comment = Sass::Tree::CommentNode.new(value, type)
        comment.line = line
        node << comment
      end

      DIRECTIVES = Set[:mixin, :include, :function, :return, :debug, :warn, :for,
        :each, :while, :if, :else, :extend, :import, :media, :charset, :content,
        :_moz_document, :at_root, :error]

      PREFIXED_DIRECTIVES = Set[:supports]

      def directive
        start_pos = source_position
        return unless tok(/@/)
        name = tok!(IDENT)
        ss

        if (dir = special_directive(name, start_pos))
          return dir
        elsif (dir = prefixed_directive(name, start_pos))
          return dir
        end

        val = almost_any_value
        val = val ? ["@#{name} "] + Sass::Util.strip_string_array(val) : ["@#{name}"]
        directive_body(val, start_pos)
      end

      def directive_body(value, start_pos)
        node = Sass::Tree::DirectiveNode.new(value)

        if tok(/\{/)
          node.has_children = true
          block_contents(node, :directive)
          tok!(/\}/)
        end

        node(node, start_pos)
      end

      def special_directive(name, start_pos)
        sym = name.gsub('-', '_').to_sym
        #nodyna <send-2973> <SD COMPLEX (change-prone variables)>
        DIRECTIVES.include?(sym) && send("#{sym}_directive", start_pos)
      end

      def prefixed_directive(name, start_pos)
        sym = deprefix(name).gsub('-', '_').to_sym
        #nodyna <send-2974> <SD COMPLEX (change-prone variables)>
        PREFIXED_DIRECTIVES.include?(sym) && send("#{sym}_directive", name, start_pos)
      end

      def mixin_directive(start_pos)
        name = tok! IDENT
        args, splat = sass_script(:parse_mixin_definition_arglist)
        ss
        block(node(Sass::Tree::MixinDefNode.new(name, args, splat), start_pos), :directive)
      end

      def include_directive(start_pos)
        name = tok! IDENT
        args, keywords, splat, kwarg_splat = sass_script(:parse_mixin_include_arglist)
        ss
        include_node = node(
          Sass::Tree::MixinNode.new(name, args, keywords, splat, kwarg_splat), start_pos)
        if tok?(/\{/)
          include_node.has_children = true
          block(include_node, :directive)
        else
          include_node
        end
      end

      def content_directive(start_pos)
        ss
        node(Sass::Tree::ContentNode.new, start_pos)
      end

      def function_directive(start_pos)
        name = tok! IDENT
        args, splat = sass_script(:parse_function_definition_arglist)
        ss
        block(node(Sass::Tree::FunctionNode.new(name, args, splat), start_pos), :function)
      end

      def return_directive(start_pos)
        node(Sass::Tree::ReturnNode.new(sass_script(:parse)), start_pos)
      end

      def debug_directive(start_pos)
        node(Sass::Tree::DebugNode.new(sass_script(:parse)), start_pos)
      end

      def warn_directive(start_pos)
        node(Sass::Tree::WarnNode.new(sass_script(:parse)), start_pos)
      end

      def for_directive(start_pos)
        tok!(/\$/)
        var = tok! IDENT
        ss

        tok!(/from/)
        from = sass_script(:parse_until, Set["to", "through"])
        ss

        @expected = '"to" or "through"'
        exclusive = (tok(/to/) || tok!(/through/)) == 'to'
        to = sass_script(:parse)
        ss

        block(node(Sass::Tree::ForNode.new(var, from, to, exclusive), start_pos), :directive)
      end

      def each_directive(start_pos)
        tok!(/\$/)
        vars = [tok!(IDENT)]
        ss
        while tok(/,/)
          ss
          tok!(/\$/)
          vars << tok!(IDENT)
          ss
        end

        tok!(/in/)
        list = sass_script(:parse)
        ss

        block(node(Sass::Tree::EachNode.new(vars, list), start_pos), :directive)
      end

      def while_directive(start_pos)
        expr = sass_script(:parse)
        ss
        block(node(Sass::Tree::WhileNode.new(expr), start_pos), :directive)
      end

      def if_directive(start_pos)
        expr = sass_script(:parse)
        ss
        node = block(node(Sass::Tree::IfNode.new(expr), start_pos), :directive)
        pos = @scanner.pos
        line = @line
        ss

        else_block(node) ||
          begin
            @scanner.pos = pos
            @line = line
            node
          end
      end

      def else_block(node)
        start_pos = source_position
        return unless tok(/@else/)
        ss
        else_node = block(
          node(Sass::Tree::IfNode.new((sass_script(:parse) if tok(/if/))), start_pos),
          :directive)
        node.add_else(else_node)
        pos = @scanner.pos
        line = @line
        ss

        else_block(node) ||
          begin
            @scanner.pos = pos
            @line = line
            node
          end
      end

      def else_directive(start_pos)
        err("Invalid CSS: @else must come after @if")
      end

      def extend_directive(start_pos)
        selector_start_pos = source_position
        @expected = "selector"
        selector = Sass::Util.strip_string_array(expr!(:almost_any_value))
        optional = tok(OPTIONAL)
        ss
        node(Sass::Tree::ExtendNode.new(selector, !!optional, range(selector_start_pos)), start_pos)
      end

      def import_directive(start_pos)
        values = []

        loop do
          values << expr!(:import_arg)
          break if use_css_import?
          break unless tok(/,/)
          ss
        end

        values
      end

      def import_arg
        start_pos = source_position
        return unless (str = string) || (uri = tok?(/url\(/i))
        if uri
          str = sass_script(:parse_string)
          ss
          media = media_query_list
          ss
          return node(Tree::CssImportNode.new(str, media.to_a), start_pos)
        end
        ss

        media = media_query_list
        if str =~ %r{^(https?:)?//} || media || use_css_import?
          return node(Sass::Tree::CssImportNode.new(
              Sass::Script::Value::String.quote(str), media.to_a), start_pos)
        end

        node(Sass::Tree::ImportNode.new(str.strip), start_pos)
      end

      def use_css_import?; false; end

      def media_directive(start_pos)
        block(node(Sass::Tree::MediaNode.new(expr!(:media_query_list).to_a), start_pos), :directive)
      end

      def media_query_list
        query = media_query
        return unless query
        queries = [query]

        ss
        while tok(/,/)
          ss; queries << expr!(:media_query)
        end
        ss

        Sass::Media::QueryList.new(queries)
      end

      def media_query
        if (ident1 = interp_ident)
          ss
          ident2 = interp_ident
          ss
          if ident2 && ident2.length == 1 && ident2[0].is_a?(String) && ident2[0].downcase == 'and'
            query = Sass::Media::Query.new([], ident1, [])
          else
            if ident2
              query = Sass::Media::Query.new(ident1, ident2, [])
            else
              query = Sass::Media::Query.new([], ident1, [])
            end
            return query unless tok(/and/i)
            ss
          end
        end

        if query
          expr = expr!(:media_expr)
        else
          expr = media_expr
          return unless expr
        end
        query ||= Sass::Media::Query.new([], [], [])
        query.expressions << expr

        ss
        while tok(/and/i)
          ss; query.expressions << expr!(:media_expr)
        end

        query
      end

      def query_expr
        interp = interpolation
        return interp if interp
        return unless tok(/\(/)
        res = ['(']
        ss
        res << sass_script(:parse)

        if tok(/:/)
          res << ': '
          ss
          res << sass_script(:parse)
        end
        res << tok!(/\)/)
        ss
        res
      end

      alias_method :media_expr, :query_expr
      alias_method :at_root_query, :query_expr

      def charset_directive(start_pos)
        name = expr!(:string)
        ss
        node(Sass::Tree::CharsetNode.new(name), start_pos)
      end

      def _moz_document_directive(start_pos)
        res = ["@-moz-document "]
        loop do
          res << str {ss} << expr!(:moz_document_function)
          if (c = tok(/,/))
            res << c
          else
            break
          end
        end
        directive_body(res.flatten, start_pos)
      end

      def moz_document_function
        val = interp_uri || _interp_string(:url_prefix) ||
          _interp_string(:domain) || function(!:allow_var) || interpolation
        return unless val
        ss
        val
      end

      def at_root_directive(start_pos)
        if tok?(/\(/) && (expr = at_root_query)
          return block(node(Sass::Tree::AtRootNode.new(expr), start_pos), :directive)
        end

        at_root_node = node(Sass::Tree::AtRootNode.new, start_pos)
        rule_node = ruleset
        return block(at_root_node, :stylesheet) unless rule_node
        at_root_node << rule_node
        at_root_node
      end

      def at_root_directive_list
        return unless (first = tok(IDENT))
        arr = [first]
        ss
        while (e = tok(IDENT))
          arr << e
          ss
        end
        arr
      end

      def error_directive(start_pos)
        node(Sass::Tree::ErrorNode.new(sass_script(:parse)), start_pos)
      end

      def supports_directive(name, start_pos)
        condition = expr!(:supports_condition)
        node = Sass::Tree::SupportsNode.new(name, condition)

        tok!(/\{/)
        node.has_children = true
        block_contents(node, :directive)
        tok!(/\}/)

        node(node, start_pos)
      end

      def supports_condition
        supports_negation || supports_operator || supports_interpolation
      end

      def supports_negation
        return unless tok(/not/i)
        ss
        Sass::Supports::Negation.new(expr!(:supports_condition_in_parens))
      end

      def supports_operator
        cond = supports_condition_in_parens
        return unless cond
        re = /and|or/i
        while (op = tok(re))
          re = /#{op}/i
          ss
          cond = Sass::Supports::Operator.new(
            cond, expr!(:supports_condition_in_parens), op)
        end
        cond
      end

      def supports_condition_in_parens
        interp = supports_interpolation
        return interp if interp
        return unless tok(/\(/); ss
        if (cond = supports_condition)
          tok!(/\)/); ss
          cond
        else
          name = sass_script(:parse)
          tok!(/:/); ss
          value = sass_script(:parse)
          tok!(/\)/); ss
          Sass::Supports::Declaration.new(name, value)
        end
      end

      def supports_interpolation
        interp = interpolation
        return unless interp
        ss
        Sass::Supports::Interpolation.new(interp)
      end

      def variable
        return unless tok(/\$/)
        start_pos = source_position
        name = tok!(IDENT)
        ss; tok!(/:/); ss

        expr = sass_script(:parse)
        while tok(/!/)
          flag_name = tok!(IDENT)
          if flag_name == 'default'
            guarded ||= true
          elsif flag_name == 'global'
            global ||= true
          else
            raise Sass::SyntaxError.new("Invalid flag \"!#{flag_name}\".", :line => @line)
          end
          ss
        end

        result = Sass::Tree::VariableNode.new(name, expr, guarded, global)
        node(result, start_pos)
      end

      def operator
        str {ss if tok(/[\/,:.=]/)}
      end

      def ruleset
        start_pos = source_position
        return unless (rules = almost_any_value)
        block(node(
          Sass::Tree::RuleNode.new(rules, range(start_pos)), start_pos), :ruleset)
      end

      def block(node, context)
        node.has_children = true
        tok!(/\{/)
        block_contents(node, context)
        tok!(/\}/)
        node
      end

      def block_contents(node, context)
        block_given? ? yield : ss_comments(node)
        node << (child = block_child(context))
        while tok(/;/) || has_children?(child)
          block_given? ? yield : ss_comments(node)
          node << (child = block_child(context))
        end
        node
      end

      def block_child(context)
        return variable || directive if context == :function
        return variable || directive || ruleset if context == :stylesheet
        variable || directive || declaration_or_ruleset
      end

      def has_children?(child_or_array)
        return false unless child_or_array
        return child_or_array.last.has_children if child_or_array.is_a?(Array)
        child_or_array.has_children
      end

      def declaration_or_ruleset
        start_pos = source_position
        declaration = try_declaration

        if declaration.nil?
          return unless (selector = almost_any_value)
        elsif declaration.is_a?(Array)
          selector = declaration
        else
          return declaration
        end

        if (additional_selector = almost_any_value)
          selector << additional_selector
        end

        block(node(
          Sass::Tree::RuleNode.new(merge(selector), range(start_pos)), start_pos), :ruleset)
      end

      def try_declaration
        name_start_pos = source_position
        if (s = tok(/[:\*\.]|\#(?!\{)/))
          name = [s, str {ss}]
          return name unless (ident = interp_ident)
          name << ident
        else
          return unless (name = interp_ident)
          name = Array(name)
        end

        if (comment = tok(COMMENT))
          name << comment
        end
        name_end_pos = source_position

        mid = [str {ss}]
        return name + mid unless tok(/:/)
        mid << ':'
        return name + mid + [':'] if tok(/:/)
        mid << str {ss}
        post_colon_whitespace = !mid.last.empty?
        could_be_selector = !post_colon_whitespace && (tok?(IDENT_START) || tok?(INTERP_START))

        value_start_pos = source_position
        value = nil
        error = catch_error do
          value = value!
          if tok?(/\{/)
            tok!(/;/) if could_be_selector
          elsif !tok?(/[;{}]/)
            tok!(/[;{}]/)
          end
        end

        if error
          rethrow error unless could_be_selector

          additional_selector = almost_any_value
          rethrow error if tok?(/;/)

          return name + mid + (additional_selector || [])
        end

        value_end_pos = source_position
        ss
        require_block = tok?(/\{/)

        node = node(Sass::Tree::PropNode.new(name.flatten.compact, value, :new),
                    name_start_pos, value_end_pos)
        node.name_source_range = range(name_start_pos, name_end_pos)
        node.value_source_range = range(value_start_pos, value_end_pos)

        return node unless require_block
        nested_properties! node
      end

      def almost_any_value
        return unless (tok = almost_any_value_token)
        sel = [tok]
        while (tok = almost_any_value_token)
          sel << tok
        end
        merge(sel)
      end

      def almost_any_value_token
        tok(%r{
          (
            \\.
          |
            (?!url\()
            [^"'/\#!;\{\}] # "
          |
            /(?![/*])
          |
            \#(?!\{)
          |
            !(?![a-z]) # TODO: never consume "!" when issue 1126 is fixed.
          )+
        }xi) || tok(COMMENT) || tok(SINGLE_LINE_COMMENT) || interp_string || interp_uri ||
                interpolation(:warn_for_color)
      end

      def declaration
        name_start_pos = source_position
        if (s = tok(/[:\*\.]|\#(?!\{)/))
          name = [s, str {ss}, *expr!(:interp_ident)]
        else
          return unless (name = interp_ident)
          name = Array(name)
        end

        if (comment = tok(COMMENT))
          name << comment
        end
        name_end_pos = source_position
        ss

        tok!(/:/)
        ss
        value_start_pos = source_position
        value = value!
        value_end_pos = source_position
        ss
        require_block = tok?(/\{/)

        node = node(Sass::Tree::PropNode.new(name.flatten.compact, value, :new),
                    name_start_pos, value_end_pos)
        node.name_source_range = range(name_start_pos, name_end_pos)
        node.value_source_range = range(value_start_pos, value_end_pos)

        return node unless require_block
        nested_properties! node
      end

      def value!
        if tok?(/\{/)
          str = Sass::Script::Tree::Literal.new(Sass::Script::Value::String.new(""))
          str.line = source_position.line
          str.source_range = range(source_position)
          return str
        end

        start_pos = source_position
        if (val = tok(STATIC_VALUE, true))
          str = Sass::Script::Tree::Literal.new(Sass::Script::Value::String.new(val.strip))
          str.line = start_pos.line
          str.source_range = range(start_pos)
          return str
        end
        sass_script(:parse)
      end

      def nested_properties!(node)
        @expected = 'expression (e.g. 1px, bold) or "{"'
        block(node, :property)
      end

      def expr(allow_var = true)
        t = term(allow_var)
        return unless t
        res = [t, str {ss}]

        while (o = operator) && (t = term(allow_var))
          res << o << t << str {ss}
        end

        res.flatten
      end

      def term(allow_var)
        e = tok(NUMBER) ||
            interp_uri ||
            function(allow_var) ||
            interp_string ||
            tok(UNICODERANGE) ||
            interp_ident ||
            tok(HEXCOLOR) ||
            (allow_var && var_expr)
        return e if e

        op = tok(/[+-]/)
        return unless op
        @expected = "number or function"
        [op,
         tok(NUMBER) || function(allow_var) || (allow_var && var_expr) || expr!(:interpolation)]
      end

      def function(allow_var)
        name = tok(FUNCTION)
        return unless name
        if name == "expression(" || name == "calc("
          str, _ = Sass::Shared.balance(@scanner, ?(, ?), 1)
          [name, str]
        else
          [name, str {ss}, expr(allow_var), tok!(/\)/)]
        end
      end

      def var_expr
        return unless tok(/\$/)
        line = @line
        var = Sass::Script::Tree::Variable.new(tok!(IDENT))
        var.line = line
        var
      end

      def interpolation(warn_for_color = false)
        return unless tok(INTERP_START)
        sass_script(:parse_interpolated, warn_for_color)
      end

      def string
        return unless tok(STRING)
        Sass::Script::Value::String.value(@scanner[1] || @scanner[2])
      end

      def interp_string
        _interp_string(:double) || _interp_string(:single)
      end

      def interp_uri
        _interp_string(:uri)
      end

      def _interp_string(type)
        start = tok(Sass::Script::Lexer::STRING_REGULAR_EXPRESSIONS[type][false])
        return unless start
        res = [start]

        mid_re = Sass::Script::Lexer::STRING_REGULAR_EXPRESSIONS[type][true]
        while @scanner[2] == '#{'
          @scanner.pos -= 2 # Don't consume the #{
          res.last.slice!(-2..-1)
          res << expr!(:interpolation) << tok(mid_re)
        end
        res
      end

      def interp_ident(start = IDENT)
        val = tok(start) || interpolation(:warn_for_color) || tok(IDENT_HYPHEN_INTERP, true)
        return unless val
        res = [val]
        while (val = tok(NAME) || interpolation(:warn_for_color))
          res << val
        end
        res
      end

      def interp_ident_or_var
        id = interp_ident
        return id if id
        var = var_expr
        return [var] if var
      end

      def str
        @strs.push ""
        yield
        @strs.last
      ensure
        @strs.pop
      end

      def str?
        pos = @scanner.pos
        line = @line
        offset = @offset
        @strs.push ""
        throw_error {yield} && @strs.last
      rescue Sass::SyntaxError
        @scanner.pos = pos
        @line = line
        @offset = offset
        nil
      ensure
        @strs.pop
      end

      def node(node, start_pos, end_pos = source_position)
        node.line = start_pos.line
        node.source_range = range(start_pos, end_pos)
        node
      end

      @sass_script_parser = Class.new(Sass::Script::Parser)
      #nodyna <send-2975> <SD TRIVIAL (public methods)>
      @sass_script_parser.send(:include, ScriptParser)

      class << self
        attr_accessor :sass_script_parser
      end

      def sass_script(*args)
        parser = self.class.sass_script_parser.new(@scanner, @line, @offset,
                                                   :filename => @filename, :importer => @importer)
        #nodyna <send-2976> <SD MODERATE (change-prone variables)>
        result = parser.send(*args)
        unless @strs.empty?
          src = result.to_sass
          @strs.each {|s| s << src}
        end
        @line = parser.line
        @offset = parser.offset
        result
      rescue Sass::SyntaxError => e
        throw(:_sass_parser_error, true) if @throw_error
        raise e
      end

      def merge(arr)
        arr && Sass::Util.merge_adjacent_strings([arr].flatten)
      end

      EXPR_NAMES = {
        :media_query => "media query (e.g. print, screen, print and screen)",
        :media_query_list => "media query (e.g. print, screen, print and screen)",
        :media_expr => "media expression (e.g. (min-device-width: 800px))",
        :at_root_query => "@at-root query (e.g. (without: media))",
        :at_root_directive_list => '* or identifier',
        :pseudo_args => "expression (e.g. fr, 2n+1)",
        :interp_ident => "identifier",
        :qualified_name => "identifier",
        :expr => "expression (e.g. 1px, bold)",
        :selector_comma_sequence => "selector",
        :string => "string",
        :import_arg => "file to import (string or url())",
        :moz_document_function => "matching function (e.g. url-prefix(), domain())",
        :supports_condition => "@supports condition (e.g. (display: flexbox))",
        :supports_condition_in_parens => "@supports condition (e.g. (display: flexbox))",
        :a_n_plus_b => "An+B expression",
        :keyframes_selector_component => "from, to, or a percentage",
        :keyframes_selector => "keyframes selector (e.g. 10%)"
      }

      TOK_NAMES = Sass::Util.to_hash(Sass::SCSS::RX.constants.map do |c|
        #nodyna <const_get-2977> <CG MODERATE (array)>
        [Sass::SCSS::RX.const_get(c), c.downcase]
      end).merge(
        IDENT => "identifier",
        /[;{}]/ => '";"',
        /\b(without|with)\b/ => '"with" or "without"'
      )

      def tok?(rx)
        @scanner.match?(rx)
      end

      def expr!(name)
        #nodyna <send-2978> <SD MODERATE (change-prone variables)>
        e = send(name)
        return e if e
        expected(EXPR_NAMES[name] || name.to_s)
      end

      def tok!(rx)
        t = tok(rx)
        return t if t
        name = TOK_NAMES[rx]

        unless name
          source = rx.source.gsub(/\\\//, '/')
          string = rx.source.gsub(/\\(.)/, '\1')
          name = source == Regexp.escape(string) ? string.inspect : rx.inspect
        end

        expected(name)
      end

      def expected(name)
        throw(:_sass_parser_error, true) if @throw_error
        self.class.expected(@scanner, @expected || name, @line)
      end

      def err(msg)
        throw(:_sass_parser_error, true) if @throw_error
        raise Sass::SyntaxError.new(msg, :line => @line)
      end

      def throw_error
        old_throw_error, @throw_error = @throw_error, false
        yield
      ensure
        @throw_error = old_throw_error
      end

      def catch_error(&block)
        old_throw_error, @throw_error = @throw_error, true
        pos = @scanner.pos
        line = @line
        offset = @offset
        expected = @expected
        if catch(:_sass_parser_error) {yield; false}
          @scanner.pos = pos
          @line = line
          @offset = offset
          @expected = expected
          {:pos => pos, :line => line, :expected => @expected, :block => block}
        end
      ensure
        @throw_error = old_throw_error
      end

      def rethrow(err)
        if @throw_error
          throw :_sass_parser_error, err
        else
          @scanner = Sass::Util::MultibyteStringScanner.new(@scanner.string)
          @scanner.pos = err[:pos]
          @line = err[:line]
          @expected = err[:expected]
          err[:block].call
        end
      end

      def self.expected(scanner, expected, line)
        pos = scanner.pos

        after = scanner.string[0...pos]
        after.gsub!(/\s*\n\s*$/, '')
        after.gsub!(/.*\n/, '')
        after = "..." + after[-15..-1] if after.size > 18

        was = scanner.rest.dup
        was.gsub!(/^\s*\n\s*/, '')
        was.gsub!(/\n.*/, '')
        was = was[0...15] + "..." if was.size > 18

        raise Sass::SyntaxError.new(
          "Invalid CSS after \"#{after}\": expected #{expected}, was \"#{was}\"",
          :line => line)
      end

      NEWLINE = "\n"

      def tok(rx, last_group_lookahead = false)
        res = @scanner.scan(rx)
        if res
          if last_group_lookahead && @scanner[-1]
            @scanner.pos -= @scanner[-1].length
            res.slice!(-@scanner[-1].length..-1)
          end

          newline_count = res.count(NEWLINE)
          if newline_count > 0
            @line += newline_count
            @offset = res[res.rindex(NEWLINE)..-1].size
          else
            @offset += res.size
          end

          @expected = nil
          if !@strs.empty? && rx != COMMENT && rx != SINGLE_LINE_COMMENT
            @strs.each {|s| s << res}
          end
          res
        end
      end

      def deprefix(str)
        str.gsub(/^-[a-zA-Z0-9]+-/, '')
      end
    end
  end
end
