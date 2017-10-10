module Rake
  module TraceOutput # :nodoc: all

    def trace_on(out, *strings)
      sep = $\ || "\n"
      if strings.empty?
        output = sep
      else
        output = strings.map { |s|
          next if s.nil?
          s =~ /#{sep}$/ ? s : s + sep
        }.join
      end
      out.print(output)
    end
  end
end
