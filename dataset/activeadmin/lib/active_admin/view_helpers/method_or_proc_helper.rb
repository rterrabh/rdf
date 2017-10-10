module MethodOrProcHelper

  def call_method_or_exec_proc(symbol_or_proc, *args)
    case symbol_or_proc
    when Symbol, String
      #nodyna <send-102> <SD COMPLEX (change-prone variables)>
      send(symbol_or_proc, *args)
    when Proc
      #nodyna <instance_exec-103> <IEX COMPLEX (block with parameters)>
      instance_exec(*args, &symbol_or_proc)
    end
  end

  def call_method_or_proc_on(receiver, *args)
    options = { exec: true }.merge(args.extract_options!)

    symbol_or_proc = args.shift

    case symbol_or_proc
    when Symbol, String
      #nodyna <send-104> <SD COMPLEX (change-prone variables)>
      receiver.public_send symbol_or_proc.to_sym, *args
    when Proc
      if options[:exec]
        #nodyna <instance_exec-105> <IEX COMPLEX (block with parameters)>
        instance_exec(receiver, *args, &symbol_or_proc)
      else
        symbol_or_proc.call(receiver, *args)
      end
    end
  end

  def render_or_call_method_or_proc_on(obj, string_symbol_or_proc, options = {})
    case string_symbol_or_proc
    when Symbol, Proc
      call_method_or_proc_on(obj, string_symbol_or_proc, options)
    when String
      string_symbol_or_proc
    end
  end

  def render_in_context(context, obj, *args)
    context ||= self # default to `self`
    case obj
    when Proc
      #nodyna <instance_exec-106> <IEX COMPLEX (block with parameters)>
      context.instance_exec *args, &obj
    when Symbol
      #nodyna <send-107> <SD COMPLEX (change-prone variables)>
      context.public_send obj, *args
    else
      obj
    end
  end
end
