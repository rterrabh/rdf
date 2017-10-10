require 'sass/script'
require 'sass/script/css_lexer'

module Sass
  module Script
    class CssParser < Parser
      private

      def lexer_class; CssLexer; end

      production :div, :unary_plus, :div

      def string
        tok = try_tok(:string)
        return number unless tok
        unless @lexer.peek && @lexer.peek.type == :begin_interpolation
          return literal_node(tok.value, tok.source_range)
        end
      end

      alias_method :interpolation, :space
      alias_method :or_expr, :div
      alias_method :unary_div, :ident
      alias_method :paren, :string
    end
  end
end
