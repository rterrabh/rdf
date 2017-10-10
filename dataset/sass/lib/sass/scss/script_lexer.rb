module Sass
  module SCSS
    module ScriptLexer
      private

      def variable
        return [:raw, "!important"] if scan(Sass::SCSS::RX::IMPORTANT)
        _variable(Sass::SCSS::RX::VARIABLE)
      end
    end
  end
end
