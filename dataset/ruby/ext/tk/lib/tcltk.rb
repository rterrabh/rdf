

require "tcltklib"


module TclTk

  @namecnt = {}

  @callback = {}
end

def TclTk.mainloop()
  print("mainloop: start\n") if $DEBUG
  TclTkLib.mainloop()
  print("mainloop: end\n") if $DEBUG
end

def TclTk.deletecallbackkey(ca)
  print("deletecallbackkey: ", ca.to_s(), "\n") if $DEBUG
  @callback.delete(ca.to_s)
end

def TclTk.dcb(ca, wid, w)
  if wid.to_s() == w
    ca.each{|i|
      TclTk.deletecallbackkey(i)
    }
  end
end

def TclTk._addcallback(ca)
  print("_addcallback: ", ca.to_s(), "\n") if $DEBUG
  @callback[ca.to_s()] = ca
end

def TclTk._callcallback(key, arg)
  print("_callcallback: ", @callback[key].inspect, "\n") if $DEBUG
  @callback[key]._call(arg)
  return ""
end

def TclTk._newname(prefix)
  if !@namecnt.key?(prefix)
    @namecnt[prefix] = 1
  else
    @namecnt[prefix] += 1
  end
  return "#{prefix}#{@namecnt[prefix]}"
end


class TclTkInterpreter

  def initialize()
    @ip = TclTkIp.new()

    if $DEBUG
      @ip._eval("proc ruby_fmt {fmt args} { puts \"ruby_fmt: $fmt $args\" ; set cmd [list ruby [format $fmt $args]] ; uplevel $cmd }")
    else
      @ip._eval("proc ruby_fmt {fmt args} { set cmd [list ruby [format $fmt $args]] ; uplevel $cmd }")
    end

    def @ip._get_eval_string(*args)
      argstr = ""
      args.each{|arg|
        argstr += " " if argstr != ""
        if (arg.respond_to?(:to_eval))
          argstr += arg.to_eval()
        else
          argstr += arg.to_s()
        end
      }
      return argstr
    end

    def @ip._eval_args(*args)
      argstr = _get_eval_string(*args)

      print("_eval: \"", argstr, "\"") if $DEBUG
      res = _eval(argstr)
      if $DEBUG
        print(" -> \"", res, "\"\n")
      elsif  _return_value() != 0
        print(res, "\n")
      end
      fail(%Q/can't eval "#{argstr}"/) if _return_value() != 0 #'
      return res
    end

    @commands = {}
    @ip._eval("info command").split(/ /).each{|comname|
      if comname =~ /^[.]/
        @commands[comname] = TclTkWidget.new(@ip, comname)
      else
        @commands[comname] = TclTkCommand.new(@ip, comname)
      end
    }
  end

  def commands()
    return @commands
  end

  def rootwidget()
    return @commands["."]
  end

  def _tcltkip()
    return @ip
  end

  def method_missing(id, *args)
    if @commands.key?(id.id2name)
      return @commands[id.id2name].e(*args)
    else
      super
    end
  end
end

class TclTkObject

  def initialize(ip, exp)
    fail("type is not TclTkIp") if !ip.kind_of?(TclTkIp)
    @ip = ip
    @exp = exp
  end

  def to_s()
    return @exp
  end
end

class TclTkCommand < TclTkObject

  def e(*args)
    return @ip._eval_args(to_s(), *args)
  end
end

class TclTkLibCommand < TclTkCommand

  def initialize(ip, name)
    super(ip._tcltkip, name)
  end
end

class TclTkVariable < TclTkObject

  def initialize(interp, dat)
    exp = TclTk._newname("v_")
    super(interp._tcltkip(), exp)
    @set = interp.commands()["set"]
    set(dat) if dat
  end


  def set(data)
    @set.e(to_s(), data.to_s())
  end

  def get()
    return @set.e(to_s())
  end
end

class TclTkWidget < TclTkCommand

  def initialize(*args)
    if args[0].kind_of?(TclTkIp)


      fail("invalid # of parameter") if args.size != 2

      ip, exp = args

      super(ip, exp)
    elsif args[0].kind_of?(TclTkInterpreter)


      interp, parent, command, *args = args

      exp = parent.to_s()
      exp += "." if exp !~ /[.]$/
      exp += TclTk._newname("w_")
      super(interp._tcltkip(), exp)
      res = @ip._eval_args(command, exp, *args)
    else
      fail("first parameter is not TclTkInterpreter")
    end
  end
end

class TclTkCallback < TclTkObject

  def initialize(interp, pr, arg = nil)
    exp = TclTk._newname("c_")
    super(interp._tcltkip(), exp)
    @pr = pr
    @arg = arg
    TclTk._addcallback(self)
  end

  def to_eval()
    if @arg
      s = %Q/{ruby_fmt {TclTk._callcallback("#{to_s()}", "%%s")} #{@arg}}/
    else
      s = %Q/{ruby_fmt {TclTk._callcallback("#{to_s()}", "%s")}}/
    end

    return s
  end

  def _call(arg)
    @pr.call(arg)
  end
end

class TclTkImage < TclTkCommand

  def initialize(interp, t, *args)
    exp = TclTk._newname("i_")
    super(interp._tcltkip(), exp)
    res = @ip._eval_args("image create", t, exp, *args)
    fail("can't create Image") if res != exp
  end
end

