require 'readline'

module Sass
  class Repl
    def initialize(options = {})
      @options = options
    end

    def run
      environment = Environment.new
      @line = 0
      loop do
        @line += 1
        unless (text = Readline.readline('>> '))
          puts
          return
        end

        Readline::HISTORY << text
        parse_input(environment, text)
      end
    end

    private

    def parse_input(environment, text)
      case text
      when Script::MATCH
        name = $1
        guarded = !!$3
        val = Script::Parser.parse($2, @line, text.size - ($3 || '').size - $2.size)

        unless guarded && environment.var(name)
          environment.set_var(name, val.perform(environment))
        end

        p environment.var(name)
      else
        p Script::Parser.parse(text, @line, 0).perform(environment)
      end
    rescue Sass::SyntaxError => e
      puts "SyntaxError: #{e.message}"
      if @options[:trace]
        e.backtrace.each do |line|
          puts "\tfrom #{line}"
        end
      end
    end
  end
end
