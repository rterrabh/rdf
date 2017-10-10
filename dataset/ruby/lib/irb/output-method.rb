
require "e2mmap"

module IRB
  class OutputMethod
    extend Exception2MessageMapper
    def_exception :NotImplementedError, "Need to define `%s'"


    def print(*opts)
      OutputMethod.Raise NotImplementedError, "print"
    end

    def printn(*opts)
      print opts.join(" "), "\n"
    end

    def printf(format, *opts)
      if /(%*)%I/ =~ format
        format, opts = parse_printf_format(format, opts)
      end
      print sprintf(format, *opts)
    end

    def parse_printf_format(format, opts)
      return format, opts if $1.size % 2 == 1
    end

    def puts(*objs)
      for obj in objs
        print(*obj)
        print "\n"
      end
    end

    def pp(*objs)
      puts(*objs.collect{|obj| obj.inspect})
    end

    def ppx(prefix, *objs)
      puts(*objs.collect{|obj| prefix+obj.inspect})
    end

  end

  class StdioOutputMethod<OutputMethod
    def print(*opts)
      STDOUT.print(*opts)
    end
  end
end
