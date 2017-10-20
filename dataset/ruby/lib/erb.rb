
require "cgi/util"

class ERB
  Revision = '$Date::                           $' # :nodoc: #'

  def self.version
    "erb.rb [2.1.0 #{ERB::Revision.split[1]}]"
  end
end

class ERB
  class Compiler # :nodoc:
    class PercentLine # :nodoc:
      def initialize(str)
        @value = str
      end
      attr_reader :value
      alias :to_s :value

      def empty?
        @value.empty?
      end
    end

    class Scanner # :nodoc:
      @scanner_map = {}
      def self.regist_scanner(klass, trim_mode, percent)
        @scanner_map[[trim_mode, percent]] = klass
      end

      def self.default_scanner=(klass)
        @default_scanner = klass
      end

      def self.make_scanner(src, trim_mode, percent)
        klass = @scanner_map.fetch([trim_mode, percent], @default_scanner)
        klass.new(src, trim_mode, percent)
      end

      def initialize(src, trim_mode, percent)
        @src = src
        @stag = nil
      end
      attr_accessor :stag

      def scan; end
    end

    class TrimScanner < Scanner # :nodoc:
      def initialize(src, trim_mode, percent)
        super
        @trim_mode = trim_mode
        @percent = percent
        if @trim_mode == '>'
          @scan_line = self.method(:trim_line1)
        elsif @trim_mode == '<>'
          @scan_line = self.method(:trim_line2)
        elsif @trim_mode == '-'
          @scan_line = self.method(:explicit_trim_line)
        else
          @scan_line = self.method(:scan_line)
        end
      end
      attr_accessor :stag

      def scan(&block)
        @stag = nil
        if @percent
          @src.each_line do |line|
            percent_line(line, &block)
          end
        else
          @scan_line.call(@src, &block)
        end
        nil
      end

      def percent_line(line, &block)
        if @stag || line[0] != ?%
          return @scan_line.call(line, &block)
        end

        line[0] = ''
        if line[0] == ?%
          @scan_line.call(line, &block)
        else
          yield(PercentLine.new(line.chomp))
        end
      end

      def scan_line(line)
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end

      def trim_line1(line)
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if token == "%>\n"
              yield('%>')
              yield(:cr)
            else
              yield(token)
            end
          end
        end
      end

      def trim_line2(line)
        head = nil
        line.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            head = token unless head
            if token == "%>\n"
              yield('%>')
              if is_erb_stag?(head)
                yield(:cr)
              else
                yield("\n")
              end
              head = nil
            else
              yield(token)
              head = nil if token == "\n"
            end
          end
        end
      end

      def explicit_trim_line(line)
        line.scan(/(.*?)(^[ \t]*<%\-|<%\-|<%%|%%>|<%=|<%#|<%|-%>\n|-%>|%>|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if @stag.nil? && /[ \t]*<%-/ =~ token
              yield('<%')
            elsif @stag && token == "-%>\n"
              yield('%>')
              yield(:cr)
            elsif @stag && token == '-%>'
              yield('%>')
            else
              yield(token)
            end
          end
        end
      end

      ERB_STAG = %w(<%= <%# <%)
      def is_erb_stag?(s)
        ERB_STAG.member?(s)
      end
    end

    Scanner.default_scanner = TrimScanner

    class SimpleScanner < Scanner # :nodoc:
      def scan
        @src.scan(/(.*?)(<%%|%%>|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end
    end

    Scanner.regist_scanner(SimpleScanner, nil, false)

    begin
      require 'strscan'
      class SimpleScanner2 < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(<%%|<%=|<%#|<%|\z)/m
          etag_reg = /(.*?)(%%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])
            yield(scanner[2])
          end
        end
      end
      Scanner.regist_scanner(SimpleScanner2, nil, false)

      class ExplicitScanner < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(^[ \t]*<%-|<%%|<%=|<%#|<%-|<%|\z)/m
          etag_reg = /(.*?)(%%>|-%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])

            elem = scanner[2]
            if /[ \t]*<%-/ =~ elem
              yield('<%')
            elsif elem == '-%>'
              yield('%>')
              yield(:cr) if scanner.scan(/(\n|\z)/)
            else
              yield(elem)
            end
          end
        end
      end
      Scanner.regist_scanner(ExplicitScanner, '-', false)

    rescue LoadError
    end

    class Buffer # :nodoc:
      def initialize(compiler, enc=nil)
        @compiler = compiler
        @line = []
        @script = enc ? "#coding:#{enc}\n" : ""
        @compiler.pre_cmd.each do |x|
          push(x)
        end
      end
      attr_reader :script

      def push(cmd)
        @line << cmd
      end

      def cr
        @script << (@line.join('; '))
        @line = []
        @script << "\n"
      end

      def close
        return unless @line
        @compiler.post_cmd.each do |x|
          push(x)
        end
        @script << (@line.join('; '))
        @line = nil
      end
    end

    def content_dump(s) # :nodoc:
      n = s.count("\n")
      if n > 0
        s.dump + "\n" * n
      else
        s.dump
      end
    end

    def add_put_cmd(out, content)
      out.push("#{@put_cmd} #{content_dump(content)}")
    end

    def add_insert_cmd(out, content)
      out.push("#{@insert_cmd}((#{content}).to_s)")
    end

    def compile(s)
      enc = s.encoding
      raise ArgumentError, "#{enc} is not ASCII compatible" if enc.dummy?
      s = s.b # see String#b
      enc = detect_magic_comment(s) || enc
      out = Buffer.new(self, enc)

      content = ''
      scanner = make_scanner(s)
      scanner.scan do |token|
        next if token.nil?
        next if token == ''
        if scanner.stag.nil?
          case token
          when PercentLine
            add_put_cmd(out, content) if content.size > 0
            content = ''
            out.push(token.to_s)
            out.cr
          when :cr
            out.cr
          when '<%', '<%=', '<%#'
            scanner.stag = token
            add_put_cmd(out, content) if content.size > 0
            content = ''
          when "\n"
            content << "\n"
            add_put_cmd(out, content)
            content = ''
          when '<%%'
            content << '<%'
          else
            content << token
          end
        else
          case token
          when '%>'
            case scanner.stag
            when '<%'
              if content[-1] == ?\n
                content.chop!
                out.push(content)
                out.cr
              else
                out.push(content)
              end
            when '<%='
              add_insert_cmd(out, content)
            when '<%#'
            end
            scanner.stag = nil
            content = ''
          when '%%>'
            content << '%>'
          else
            content << token
          end
        end
      end
      add_put_cmd(out, content) if content.size > 0
      out.close
      return out.script, enc
    end

    def prepare_trim_mode(mode) # :nodoc:
      case mode
      when 1
        return [false, '>']
      when 2
        return [false, '<>']
      when 0
        return [false, nil]
      when String
        perc = mode.include?('%')
        if mode.include?('-')
          return [perc, '-']
        elsif mode.include?('<>')
          return [perc, '<>']
        elsif mode.include?('>')
          return [perc, '>']
        else
          [perc, nil]
        end
      else
        return [false, nil]
      end
    end

    def make_scanner(src) # :nodoc:
      Scanner.make_scanner(src, @trim_mode, @percent)
    end

    def initialize(trim_mode)
      @percent, @trim_mode = prepare_trim_mode(trim_mode)
      @put_cmd = 'print'
      @insert_cmd = @put_cmd
      @pre_cmd = []
      @post_cmd = []
    end
    attr_reader :percent, :trim_mode

    attr_accessor :put_cmd

    attr_accessor :insert_cmd

    attr_accessor :pre_cmd

    attr_accessor :post_cmd

    private
    def detect_magic_comment(s)
      if /\A<%#(.*)%>/ =~ s or (@percent and /\A%#(.*)/ =~ s)
        comment = $1
        comment = $1 if comment[/-\*-\s*(.*?)\s*-*-$/]
        if %r"coding\s*[=:]\s*([[:alnum:]\-_]+)" =~ comment
          enc = $1.sub(/-(?:mac|dos|unix)/i, '')
          Encoding.find(enc)
        end
      end
    end
  end
end

class ERB
  def initialize(str, safe_level=nil, trim_mode=nil, eoutvar='_erbout')
    @safe_level = safe_level
    compiler = make_compiler(trim_mode)
    set_eoutvar(compiler, eoutvar)
    @src, @encoding = *compiler.compile(str)
    @filename = nil
    @lineno = 0
  end


  def make_compiler(trim_mode)
    ERB::Compiler.new(trim_mode)
  end

  attr_reader :src

  attr_reader :encoding

  attr_accessor :filename

  attr_accessor :lineno

  def location=((filename, lineno))
    @filename = filename
    @lineno = lineno if lineno
  end

  def set_eoutvar(compiler, eoutvar = '_erbout')
    compiler.put_cmd = "#{eoutvar}.concat"
    compiler.insert_cmd = "#{eoutvar}.concat"
    compiler.pre_cmd = ["#{eoutvar} = ''"]
    compiler.post_cmd = ["#{eoutvar}.force_encoding(__ENCODING__)"]
  end

  def run(b=new_toplevel)
    print self.result(b)
  end

  def result(b=new_toplevel)
    if @safe_level
      proc {
        $SAFE = @safe_level
        #nodyna <eval-2170> <EV COMPLEX (change-prone variables)>
        eval(@src, b, (@filename || '(erb)'), @lineno)
      }.call
    else
      #nodyna <eval-2171> <EV COMPLEX (change-prone variables)>
      eval(@src, b, (@filename || '(erb)'), @lineno)
    end
  end


  def new_toplevel
    TOPLEVEL_BINDING.dup
  end
  private :new_toplevel

  def def_method(mod, methodname, fname='(ERB)')
    src = self.src
    magic_comment = "#coding:#{@encoding}\n"
    #nodyna <module_eval-2172> <ME COMPLEX (block execution)>
    mod.module_eval do
      #nodyna <eval-2173> <EV COMPLEX (method definition)>
      eval(magic_comment + "def #{methodname}\n" + src + "\nend\n", binding, fname, -2)
    end
  end

  def def_module(methodname='erb')
    mod = Module.new
    def_method(mod, methodname, @filename || '(ERB)')
    mod
  end

  def def_class(superklass=Object, methodname='result')
    cls = Class.new(superklass)
    def_method(cls, methodname, @filename || '(ERB)')
    cls
  end
end

class ERB
  module Util
    public
    def html_escape(s)
      CGI.escapeHTML(s.to_s)
    end
    alias h html_escape
    module_function :h
    module_function :html_escape

    def url_encode(s)
      s.to_s.b.gsub(/[^a-zA-Z0-9_\-.]/n) { |m|
        sprintf("%%%02X", m.unpack("C")[0])
      }
    end
    alias u url_encode
    module_function :u
    module_function :url_encode
  end
end

class ERB
  module DefMethod
    public
    def def_erb_method(methodname, erb_or_fname)
      if erb_or_fname.kind_of? String
        fname = erb_or_fname
        erb = ERB.new(File.read(fname))
        erb.def_method(self, methodname, fname)
      else
        erb = erb_or_fname
        erb.def_method(self, methodname, erb.filename || '(ERB)')
      end
    end
    module_function :def_erb_method
  end
end
