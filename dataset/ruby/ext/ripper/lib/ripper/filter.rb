
require 'ripper/lexer'

class Ripper

  class Filter

    def initialize(src, filename = '-', lineno = 1)
      @__lexer = Lexer.new(src, filename, lineno)
      @__line = nil
      @__col = nil
    end

    def filename
      @__lexer.filename
    end

    def lineno
      @__line
    end

    def column
      @__col
    end

    def parse(init = nil)
      data = init
      @__lexer.lex.each do |pos, event, tok|
        @__line, @__col = *pos
        data = if respond_to?(event, true)
               then __send__(event, tok, data)
               else on_default(event, tok, data)
               end
      end
      data
    end

    private

    def on_default(event, token, data)
      data
    end

  end

end
