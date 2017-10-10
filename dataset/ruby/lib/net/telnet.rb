
require "net/protocol"
require "English"

module Net

  class Telnet

    IAC   = 255.chr # "\377" # "\xff" # interpret as command
    DONT  = 254.chr # "\376" # "\xfe" # you are not to use option
    DO    = 253.chr # "\375" # "\xfd" # please, you use option
    WONT  = 252.chr # "\374" # "\xfc" # I won't use option
    WILL  = 251.chr # "\373" # "\xfb" # I will use option
    SB    = 250.chr # "\372" # "\xfa" # interpret as subnegotiation
    GA    = 249.chr # "\371" # "\xf9" # you may reverse the line
    EL    = 248.chr # "\370" # "\xf8" # erase the current line
    EC    = 247.chr # "\367" # "\xf7" # erase the current character
    AYT   = 246.chr # "\366" # "\xf6" # are you there
    AO    = 245.chr # "\365" # "\xf5" # abort output--but let prog finish
    IP    = 244.chr # "\364" # "\xf4" # interrupt process--permanently
    BREAK = 243.chr # "\363" # "\xf3" # break
    DM    = 242.chr # "\362" # "\xf2" # data mark--for connect. cleaning
    NOP   = 241.chr # "\361" # "\xf1" # nop
    SE    = 240.chr # "\360" # "\xf0" # end sub negotiation
    EOR   = 239.chr # "\357" # "\xef" # end of record (transparent mode)
    ABORT = 238.chr # "\356" # "\xee" # Abort process
    SUSP  = 237.chr # "\355" # "\xed" # Suspend process
    EOF   = 236.chr # "\354" # "\xec" # End of file
    SYNCH = 242.chr # "\362" # "\xf2" # for telfunc calls

    OPT_BINARY         =   0.chr # "\000" # "\x00" # Binary Transmission
    OPT_ECHO           =   1.chr # "\001" # "\x01" # Echo
    OPT_RCP            =   2.chr # "\002" # "\x02" # Reconnection
    OPT_SGA            =   3.chr # "\003" # "\x03" # Suppress Go Ahead
    OPT_NAMS           =   4.chr # "\004" # "\x04" # Approx Message Size Negotiation
    OPT_STATUS         =   5.chr # "\005" # "\x05" # Status
    OPT_TM             =   6.chr # "\006" # "\x06" # Timing Mark
    OPT_RCTE           =   7.chr # "\a"   # "\x07" # Remote Controlled Trans and Echo
    OPT_NAOL           =   8.chr # "\010" # "\x08" # Output Line Width
    OPT_NAOP           =   9.chr # "\t"   # "\x09" # Output Page Size
    OPT_NAOCRD         =  10.chr # "\n"   # "\x0a" # Output Carriage-Return Disposition
    OPT_NAOHTS         =  11.chr # "\v"   # "\x0b" # Output Horizontal Tab Stops
    OPT_NAOHTD         =  12.chr # "\f"   # "\x0c" # Output Horizontal Tab Disposition
    OPT_NAOFFD         =  13.chr # "\r"   # "\x0d" # Output Formfeed Disposition
    OPT_NAOVTS         =  14.chr # "\016" # "\x0e" # Output Vertical Tabstops
    OPT_NAOVTD         =  15.chr # "\017" # "\x0f" # Output Vertical Tab Disposition
    OPT_NAOLFD         =  16.chr # "\020" # "\x10" # Output Linefeed Disposition
    OPT_XASCII         =  17.chr # "\021" # "\x11" # Extended ASCII
    OPT_LOGOUT         =  18.chr # "\022" # "\x12" # Logout
    OPT_BM             =  19.chr # "\023" # "\x13" # Byte Macro
    OPT_DET            =  20.chr # "\024" # "\x14" # Data Entry Terminal
    OPT_SUPDUP         =  21.chr # "\025" # "\x15" # SUPDUP
    OPT_SUPDUPOUTPUT   =  22.chr # "\026" # "\x16" # SUPDUP Output
    OPT_SNDLOC         =  23.chr # "\027" # "\x17" # Send Location
    OPT_TTYPE          =  24.chr # "\030" # "\x18" # Terminal Type
    OPT_EOR            =  25.chr # "\031" # "\x19" # End of Record
    OPT_TUID           =  26.chr # "\032" # "\x1a" # TACACS User Identification
    OPT_OUTMRK         =  27.chr # "\e"   # "\x1b" # Output Marking
    OPT_TTYLOC         =  28.chr # "\034" # "\x1c" # Terminal Location Number
    OPT_3270REGIME     =  29.chr # "\035" # "\x1d" # Telnet 3270 Regime
    OPT_X3PAD          =  30.chr # "\036" # "\x1e" # X.3 PAD
    OPT_NAWS           =  31.chr # "\037" # "\x1f" # Negotiate About Window Size
    OPT_TSPEED         =  32.chr # " "    # "\x20" # Terminal Speed
    OPT_LFLOW          =  33.chr # "!"    # "\x21" # Remote Flow Control
    OPT_LINEMODE       =  34.chr # "\""   # "\x22" # Linemode
    OPT_XDISPLOC       =  35.chr # "#"    # "\x23" # X Display Location
    OPT_OLD_ENVIRON    =  36.chr # "$"    # "\x24" # Environment Option
    OPT_AUTHENTICATION =  37.chr # "%"    # "\x25" # Authentication Option
    OPT_ENCRYPT        =  38.chr # "&"    # "\x26" # Encryption Option
    OPT_NEW_ENVIRON    =  39.chr # "'"    # "\x27" # New Environment Option
    OPT_EXOPL          = 255.chr # "\377" # "\xff" # Extended-Options-List

    NULL = "\000"
    CR   = "\015"
    LF   = "\012"
    EOL  = CR + LF
    REVISION = '$Id$'

    def initialize(options) # :yield: mesg
      @options = options
      @options["Host"]       = "localhost"   unless @options.has_key?("Host")
      @options["Port"]       = 23            unless @options.has_key?("Port")
      @options["Prompt"]     = /[$%#>] \z/n  unless @options.has_key?("Prompt")
      @options["Timeout"]    = 10            unless @options.has_key?("Timeout")
      @options["Waittime"]   = 0             unless @options.has_key?("Waittime")
      unless @options.has_key?("Binmode")
        @options["Binmode"]    = false
      else
        unless (true == @options["Binmode"] or false == @options["Binmode"])
          raise ArgumentError, "Binmode option must be true or false"
        end
      end

      unless @options.has_key?("Telnetmode")
        @options["Telnetmode"] = true
      else
        unless (true == @options["Telnetmode"] or false == @options["Telnetmode"])
          raise ArgumentError, "Telnetmode option must be true or false"
        end
      end

      @telnet_option = { "SGA" => false, "BINARY" => false }

      if @options.has_key?("Output_log")
        @log = File.open(@options["Output_log"], 'a+')
        @log.sync = true
        @log.binmode
      end

      if @options.has_key?("Dump_log")
        @dumplog = File.open(@options["Dump_log"], 'a+')
        @dumplog.sync = true
        @dumplog.binmode
        def @dumplog.log_dump(dir, x)  # :nodoc:
          len = x.length
          addr = 0
          offset = 0
          while 0 < len
            if len < 16
              line = x[offset, len]
            else
              line = x[offset, 16]
            end
            hexvals = line.unpack('H*')[0]
            hexvals += ' ' * (32 - hexvals.length)
            hexvals = format("%s %s %s %s  " * 4, *hexvals.unpack('a2' * 16))
            line = line.gsub(/[\000-\037\177-\377]/n, '.')
            printf "%s 0x%5.5x: %s%s\n", dir, addr, hexvals, line
            addr += 16
            offset += 16
            len -= 16
          end
          print "\n"
        end
      end

      if @options.has_key?("Proxy")
        if @options["Proxy"].kind_of?(Net::Telnet)
          @sock = @options["Proxy"].sock
        elsif @options["Proxy"].kind_of?(IO)
          @sock = @options["Proxy"]
        else
          raise "Error: Proxy must be an instance of Net::Telnet or IO."
        end
      else
        message = "Trying " + @options["Host"] + "...\n"
        yield(message) if block_given?
        @log.write(message) if @options.has_key?("Output_log")
        @dumplog.log_dump('#', message) if @options.has_key?("Dump_log")

        begin
          if @options["Timeout"] == false
            @sock = TCPSocket.open(@options["Host"], @options["Port"])
          else
            Timeout.timeout(@options["Timeout"], Net::OpenTimeout) do
              @sock = TCPSocket.open(@options["Host"], @options["Port"])
            end
          end
        rescue Net::OpenTimeout
          raise Net::OpenTimeout, "timed out while opening a connection to the host"
        rescue
          @log.write($ERROR_INFO.to_s + "\n") if @options.has_key?("Output_log")
          @dumplog.log_dump('#', $ERROR_INFO.to_s + "\n") if @options.has_key?("Dump_log")
          raise
        end
        @sock.sync = true
        @sock.binmode

        message = "Connected to " + @options["Host"] + ".\n"
        yield(message) if block_given?
        @log.write(message) if @options.has_key?("Output_log")
        @dumplog.log_dump('#', message) if @options.has_key?("Dump_log")
      end

    end # initialize

    attr_reader :sock

    def telnetmode(mode = nil)
      case mode
      when nil
        @options["Telnetmode"]
      when true, false
        @options["Telnetmode"] = mode
      else
        raise ArgumentError, "argument must be true or false, or missing"
      end
    end

    def telnetmode=(mode)
      if (true == mode or false == mode)
        @options["Telnetmode"] = mode
      else
        raise ArgumentError, "argument must be true or false"
      end
    end

    def binmode(mode = nil)
      case mode
      when nil
        @options["Binmode"]
      when true, false
        @options["Binmode"] = mode
      else
        raise ArgumentError, "argument must be true or false"
      end
    end

    def binmode=(mode)
      if (true == mode or false == mode)
        @options["Binmode"] = mode
      else
        raise ArgumentError, "argument must be true or false"
      end
    end

    def preprocess(string)
      string = string.gsub(/#{CR}#{NULL}/no, CR) if @options["Telnetmode"]

      string = string.gsub(/#{EOL}/no, "\n") unless @options["Binmode"]

      string = string.gsub(/#{NULL}/no, '') unless @options["Binmode"]

      string.gsub(/#{IAC}(
                   [#{IAC}#{AO}#{AYT}#{DM}#{IP}#{NOP}]|
                   [#{DO}#{DONT}#{WILL}#{WONT}]
                     [#{OPT_BINARY}-#{OPT_NEW_ENVIRON}#{OPT_EXOPL}]|
                 )/xno) do
        if    IAC == $1  # handle escaped IAC characters
          IAC
        elsif AYT == $1  # respond to "IAC AYT" (are you there)
          self.write("nobody here but us pigeons" + EOL)
          ''
        elsif DO[0] == $1[0]  # respond to "IAC DO x"
          if OPT_BINARY[0] == $1[1]
            @telnet_option["BINARY"] = true
            self.write(IAC + WILL + OPT_BINARY)
          else
            self.write(IAC + WONT + $1[1..1])
          end
          ''
        elsif DONT[0] == $1[0]  # respond to "IAC DON'T x" with "IAC WON'T x"
          self.write(IAC + WONT + $1[1..1])
          ''
        elsif WILL[0] == $1[0]  # respond to "IAC WILL x"
          if    OPT_BINARY[0] == $1[1]
            self.write(IAC + DO + OPT_BINARY)
          elsif OPT_ECHO[0] == $1[1]
            self.write(IAC + DO + OPT_ECHO)
          elsif OPT_SGA[0]  == $1[1]
            @telnet_option["SGA"] = true
            self.write(IAC + DO + OPT_SGA)
          else
            self.write(IAC + DONT + $1[1..1])
          end
          ''
        elsif WONT[0] == $1[0]  # respond to "IAC WON'T x"
          if    OPT_ECHO[0] == $1[1]
            self.write(IAC + DONT + OPT_ECHO)
          elsif OPT_SGA[0]  == $1[1]
            @telnet_option["SGA"] = false
            self.write(IAC + DONT + OPT_SGA)
          else
            self.write(IAC + DONT + $1[1..1])
          end
          ''
        else
          ''
        end
      end
    end # preprocess

    def waitfor(options) # :yield: recvdata
      time_out = @options["Timeout"]
      waittime = @options["Waittime"]
      fail_eof = @options["FailEOF"]

      if options.kind_of?(Hash)
        prompt   = if options.has_key?("Match")
                     options["Match"]
                   elsif options.has_key?("Prompt")
                     options["Prompt"]
                   elsif options.has_key?("String")
                     Regexp.new( Regexp.quote(options["String"]) )
                   end
        time_out = options["Timeout"]  if options.has_key?("Timeout")
        waittime = options["Waittime"] if options.has_key?("Waittime")
        fail_eof = options["FailEOF"]  if options.has_key?("FailEOF")
      else
        prompt = options
      end

      if time_out == false
        time_out = nil
      end

      line = ''
      buf = ''
      rest = ''
      until(prompt === line and not IO::select([@sock], nil, nil, waittime))
        unless IO::select([@sock], nil, nil, time_out)
          raise Net::ReadTimeout, "timed out while waiting for more data"
        end
        begin
          c = @sock.readpartial(1024 * 1024)
          @dumplog.log_dump('<', c) if @options.has_key?("Dump_log")
          if @options["Telnetmode"]
            c = rest + c
            if Integer(c.rindex(/#{IAC}#{SE}/no) || 0) <
               Integer(c.rindex(/#{IAC}#{SB}/no) || 0)
              buf = preprocess(c[0 ... c.rindex(/#{IAC}#{SB}/no)])
              rest = c[c.rindex(/#{IAC}#{SB}/no) .. -1]
            elsif pt = c.rindex(/#{IAC}[^#{IAC}#{AO}#{AYT}#{DM}#{IP}#{NOP}]?\z/no) ||
                       c.rindex(/\r\z/no)
              buf = preprocess(c[0 ... pt])
              rest = c[pt .. -1]
            else
              buf = preprocess(c)
              rest = ''
            end
         else
           buf = rest + c
           rest = ''
           unless @options["Binmode"]
             if pt = buf.rindex(/\r\z/no)
               buf = buf[0 ... pt]
               rest = buf[pt .. -1]
             end
             buf.gsub!(/#{EOL}/no, "\n")
           end
          end
          @log.print(buf) if @options.has_key?("Output_log")
          line += buf
          yield buf if block_given?
        rescue EOFError # End of file reached
          raise if fail_eof
          if line == ''
            line = nil
            yield nil if block_given?
          end
          break
        end
      end
      line
    end

    def write(string)
      length = string.length
      while 0 < length
        IO::select(nil, [@sock])
        @dumplog.log_dump('>', string[-length..-1]) if @options.has_key?("Dump_log")
        length -= @sock.syswrite(string[-length..-1])
      end
    end

    def print(string)
      string = string.gsub(/#{IAC}/no, IAC + IAC) if @options["Telnetmode"]

      if @options["Binmode"]
        self.write(string)
      else
        if @telnet_option["BINARY"] and @telnet_option["SGA"]
          self.write(string.gsub(/\n/n, CR))
        elsif @telnet_option["SGA"]
          self.write(string.gsub(/\n/n, CR + NULL))
        else
          self.write(string.gsub(/\n/n, EOL))
        end
      end
    end

    def puts(string)
      self.print(string + "\n")
    end

    def cmd(options) # :yield: recvdata
      match    = @options["Prompt"]
      time_out = @options["Timeout"]
      fail_eof = @options["FailEOF"]

      if options.kind_of?(Hash)
        string   = options["String"]
        match    = options["Match"]   if options.has_key?("Match")
        time_out = options["Timeout"] if options.has_key?("Timeout")
        fail_eof = options["FailEOF"] if options.has_key?("FailEOF")
      else
        string = options
      end

      self.puts(string)
      if block_given?
        waitfor({"Prompt" => match, "Timeout" => time_out, "FailEOF" => fail_eof}){|c| yield c }
      else
        waitfor({"Prompt" => match, "Timeout" => time_out, "FailEOF" => fail_eof})
      end
    end

    def login(options, password = nil) # :yield: recvdata
      login_prompt = /[Ll]ogin[: ]*\z/n
      password_prompt = /[Pp]ass(?:word|phrase)[: ]*\z/n
      if options.kind_of?(Hash)
        username = options["Name"]
        password = options["Password"]
        login_prompt = options["LoginPrompt"] if options["LoginPrompt"]
        password_prompt = options["PasswordPrompt"] if options["PasswordPrompt"]
      else
        username = options
      end

      if block_given?
        line = waitfor(login_prompt){|c| yield c }
        if password
          line += cmd({"String" => username,
                       "Match" => password_prompt}){|c| yield c }
          line += cmd(password){|c| yield c }
        else
          line += cmd(username){|c| yield c }
        end
      else
        line = waitfor(login_prompt)
        if password
          line += cmd({"String" => username,
                       "Match" => password_prompt})
          line += cmd(password)
        else
          line += cmd(username)
        end
      end
      line
    end

    def close
      @sock.close
    end

  end  # class Telnet
end  # module Net

