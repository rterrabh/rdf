module Sass
  module SCSS
    module ScriptParser
      private

      def lexer_class
        klass = Class.new(super)
        #nodyna <send-2981> <SD TRIVIAL (public methods)>
        klass.send(:include, ScriptLexer)
        klass
      end

      def assert_done
        @lexer.unpeek!
      end
    end
  end
end
