class MemInfo

  def mem_total
    @mem_total ||=
      begin
        system = `uname`.strip
        if system == "Darwin"
          s = `sysctl -n hw.memsize`.strip
          s.to_i / 1.kilobyte
        else
          s = `grep MemTotal /proc/meminfo`
          /(\d+)/.match(s)[0].try(:to_i)
        end
      rescue
        nil
      end
  end

end
