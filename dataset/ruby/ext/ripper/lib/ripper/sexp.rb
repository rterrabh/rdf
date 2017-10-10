
require 'ripper/core'

class Ripper

  def Ripper.sexp(src, filename = '-', lineno = 1)
    builder = SexpBuilderPP.new(src, filename, lineno)
    sexp = builder.parse
    sexp unless builder.error?
  end

  def Ripper.sexp_raw(src, filename = '-', lineno = 1)
    builder = SexpBuilder.new(src, filename, lineno)
    sexp = builder.parse
    sexp unless builder.error?
  end

  class SexpBuilderPP < ::Ripper   #:nodoc:
    private

    PARSER_EVENT_TABLE.each do |event, arity|
      if /_new\z/ =~ event.to_s and arity == 0
        #nodyna <module_eval-1532> <not yet classified>
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}
            []
          end
        End
      elsif /_add\z/ =~ event.to_s
        #nodyna <module_eval-1533> <not yet classified>
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}(list, item)
            list.push item
            list
          end
        End
      else
        #nodyna <module_eval-1534> <not yet classified>
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}(*args)
            [:#{event}, *args]
          end
        End
      end
    end

    SCANNER_EVENTS.each do |event|
      #nodyna <module_eval-1535> <not yet classified>
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(tok)
          [:@#{event}, tok, [lineno(), column()]]
        end
      End
    end
  end

  class SexpBuilder < ::Ripper   #:nodoc:
    private

    PARSER_EVENTS.each do |event|
      #nodyna <module_eval-1536> <not yet classified>
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(*args)
          args.unshift :#{event}
          args
        end
      End
    end

    SCANNER_EVENTS.each do |event|
      #nodyna <module_eval-1537> <not yet classified>
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(tok)
          [:@#{event}, tok, [lineno(), column()]]
        end
      End
    end
  end

end
