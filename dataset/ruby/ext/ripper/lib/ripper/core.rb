
require 'ripper.so'

class Ripper

  def Ripper.parse(src, filename = '(ripper)', lineno = 1)
    new(src, filename, lineno).parse
  end

  PARSER_EVENTS = PARSER_EVENT_TABLE.keys

  SCANNER_EVENTS = SCANNER_EVENT_TABLE.keys

  EVENTS = PARSER_EVENTS + SCANNER_EVENTS

  private


  PARSER_EVENT_TABLE.each do |id, arity|
    #nodyna <module_eval-1538> <not yet classified>
    module_eval(<<-End, __FILE__, __LINE__ + 1)
      def on_#{id}(#{ ('a'..'z').to_a[0, arity].join(', ') })
      end
    End
  end

  def warn(fmt, *args)
  end

  def warning(fmt, *args)
  end

  def compile_error(msg)
  end


  SCANNER_EVENTS.each do |id|
    #nodyna <module_eval-1539> <not yet classified>
    module_eval(<<-End, __FILE__, __LINE__ + 1)
      def on_#{id}(token)
        token
      end
    End
  end

end
