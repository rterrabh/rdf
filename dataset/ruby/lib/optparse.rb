

class OptionParser
  NoArgument = [NO_ARGUMENT = :NONE, nil].freeze
  RequiredArgument = [REQUIRED_ARGUMENT = :REQUIRED, true].freeze
  OptionalArgument = [OPTIONAL_ARGUMENT = :OPTIONAL, false].freeze

  module Completion
    def self.regexp(key, icase)
      Regexp.new('\A' + Regexp.quote(key).gsub(/\w+\b/, '\&\w*'), icase)
    end

    def self.candidate(key, icase = false, pat = nil, &block)
      pat ||= Completion.regexp(key, icase)
      candidates = []
      block.call do |k, *v|
        (if Regexp === k
           kn = nil
           k === key
         else
           kn = defined?(k.id2name) ? k.id2name : k
           pat === kn
         end) or next
        v << k if v.empty?
        candidates << [k, v, kn]
      end
      candidates
    end

    def candidate(key, icase = false, pat = nil)
      Completion.candidate(key, icase, pat, &method(:each))
    end

    public
    def complete(key, icase = false, pat = nil)
      candidates = candidate(key, icase, pat, &method(:each)).sort_by {|k, v, kn| kn.size}
      if candidates.size == 1
        canon, sw, * = candidates[0]
      elsif candidates.size > 1
        canon, sw, cn = candidates.shift
        candidates.each do |k, v, kn|
          next if sw == v
          if String === cn and String === kn
            if cn.rindex(kn, 0)
              canon, sw, cn = k, v, kn
              next
            elsif kn.rindex(cn, 0)
              next
            end
          end
          throw :ambiguous, key
        end
      end
      if canon
        block_given? or return key, *sw
        yield(key, *sw)
      end
    end

    def convert(opt = nil, val = nil, *)
      val
    end
  end


  class OptionMap < Hash
    include Completion
  end


  class Switch
    attr_reader :pattern, :conv, :short, :long, :arg, :desc, :block

    def self.guess(arg)
      case arg
      when ""
        t = self
      when /\A=?\[/
        t = Switch::OptionalArgument
      when /\A\s+\[/
        t = Switch::PlacedArgument
      else
        t = Switch::RequiredArgument
      end
      self >= t or incompatible_argument_styles(arg, t)
      t
    end

    def self.incompatible_argument_styles(arg, t)
      raise(ArgumentError, "#{arg}: incompatible argument styles\n  #{self}, #{t}",
            ParseError.filter_backtrace(caller(2)))
    end

    def self.pattern
      NilClass
    end

    def initialize(pattern = nil, conv = nil,
                   short = nil, long = nil, arg = nil,
                   desc = ([] if short or long), block = Proc.new)
      raise if Array === pattern
      @pattern, @conv, @short, @long, @arg, @desc, @block =
        pattern, conv, short, long, arg, desc, block
    end

    def parse_arg(arg)
      pattern or return nil, [arg]
      unless m = pattern.match(arg)
        yield(InvalidArgument, arg)
        return arg, []
      end
      if String === m
        m = [s = m]
      else
        m = m.to_a
        s = m[0]
        return nil, m unless String === s
      end
      raise InvalidArgument, arg unless arg.rindex(s, 0)
      return nil, m if s.length == arg.length
      yield(InvalidArgument, arg) # didn't match whole arg
      return arg[s.length..-1], m
    end
    private :parse_arg

    def conv_arg(arg, val = [])
      if conv
        val = conv.call(*val)
      else
        val = proc {|v| v}.call(*val)
      end
      return arg, block, val
    end
    private :conv_arg

    def summarize(sdone = [], ldone = [], width = 1, max = width - 1, indent = "")
      sopts, lopts = [], [], nil
      @short.each {|s| sdone.fetch(s) {sopts << s}; sdone[s] = true} if @short
      @long.each {|s| ldone.fetch(s) {lopts << s}; ldone[s] = true} if @long
      return if sopts.empty? and lopts.empty? # completely hidden

      left = [sopts.join(', ')]
      right = desc.dup

      while s = lopts.shift
        l = left[-1].length + s.length
        l += arg.length if left.size == 1 && arg
        l < max or sopts.empty? or left << ''
        left[-1] << if left[-1].empty? then ' ' * 4 else ', ' end << s
      end

      if arg
        left[0] << (left[1] ? arg.sub(/\A(\[?)=/, '\1') + ',' : arg)
      end
      mlen = left.collect {|ss| ss.length}.max.to_i
      while mlen > width and l = left.shift
        mlen = left.collect {|ss| ss.length}.max.to_i if l.length == mlen
        if l.length < width and (r = right[0]) and !r.empty?
          l = l.to_s.ljust(width) + ' ' + r
          right.shift
        end
        yield(indent + l)
      end

      while begin l = left.shift; r = right.shift; l or r end
        l = l.to_s.ljust(width) + ' ' + r if r and !r.empty?
        yield(indent + l)
      end

      self
    end

    def add_banner(to)  # :nodoc:
      unless @short or @long
        s = desc.join
        to << " [" + s + "]..." unless s.empty?
      end
      to
    end

    def match_nonswitch?(str)  # :nodoc:
      @pattern =~ str unless @short or @long
    end

    def switch_name
      (long.first || short.first).sub(/\A-+(?:\[no-\])?/, '')
    end

    def compsys(sdone, ldone)   # :nodoc:
      sopts, lopts = [], []
      @short.each {|s| sdone.fetch(s) {sopts << s}; sdone[s] = true} if @short
      @long.each {|s| ldone.fetch(s) {lopts << s}; ldone[s] = true} if @long
      return if sopts.empty? and lopts.empty? # completely hidden

      (sopts+lopts).each do |opt|
        if /^--\[no-\](.+)$/ =~ opt
          o = $1
          yield("--#{o}", desc.join(""))
          yield("--no-#{o}", desc.join(""))
        else
          yield("#{opt}", desc.join(""))
        end
      end
    end

    class NoArgument < self

      def parse(arg, argv)
        yield(NeedlessArgument, arg) if arg
        conv_arg(arg)
      end

      def self.incompatible_argument_styles(*)
      end

      def self.pattern
        Object
      end
    end

    class RequiredArgument < self

      def parse(arg, argv)
        unless arg
          raise MissingArgument if argv.empty?
          arg = argv.shift
        end
        conv_arg(*parse_arg(arg, &method(:raise)))
      end
    end

    class OptionalArgument < self

      def parse(arg, argv, &error)
        if arg
          conv_arg(*parse_arg(arg, &error))
        else
          conv_arg(arg)
        end
      end
    end

    class PlacedArgument < self

      def parse(arg, argv, &error)
        if !(val = arg) and (argv.empty? or /\A-/ =~ (val = argv[0]))
          return nil, block, nil
        end
        opt = (val = parse_arg(val, &error))[1]
        val = conv_arg(*val)
        if opt and !arg
          argv.shift
        else
          val[0] = nil
        end
        val
      end
    end
  end

  class List
    attr_reader :atype

    attr_reader :short

    attr_reader :long

    attr_reader :list

    def initialize
      @atype = {}
      @short = OptionMap.new
      @long = OptionMap.new
      @list = []
    end

    def accept(t, pat = /.*/m, &block)
      if pat
        pat.respond_to?(:match) or
          raise TypeError, "has no `match'", ParseError.filter_backtrace(caller(2))
      else
        pat = t if t.respond_to?(:match)
      end
      unless block
        block = pat.method(:convert).to_proc if pat.respond_to?(:convert)
      end
      @atype[t] = [pat, block]
    end

    def reject(t)
      @atype.delete(t)
    end

    def update(sw, sopts, lopts, nsw = nil, nlopts = nil)
      sopts.each {|o| @short[o] = sw} if sopts
      lopts.each {|o| @long[o] = sw} if lopts
      nlopts.each {|o| @long[o] = nsw} if nsw and nlopts
      used = @short.invert.update(@long.invert)
      @list.delete_if {|o| Switch === o and !used[o]}
    end
    private :update

    def prepend(*args)
      update(*args)
      @list.unshift(args[0])
    end

    def append(*args)
      update(*args)
      @list.push(args[0])
    end

    def search(id, key)
      if list = __send__(id)
        val = list.fetch(key) {return nil}
        block_given? ? yield(val) : val
      end
    end

    def complete(id, opt, icase = false, *pat, &block)
      __send__(id).complete(opt, icase, *pat, &block)
    end

    def each_option(&block)
      list.each(&block)
    end

    def summarize(*args, &block)
      sum = []
      list.reverse_each do |opt|
        if opt.respond_to?(:summarize) # perhaps OptionParser::Switch
          s = []
          opt.summarize(*args) {|l| s << l}
          sum.concat(s.reverse)
        elsif !opt or opt.empty?
          sum << ""
        elsif opt.respond_to?(:each_line)
          sum.concat([*opt.each_line].reverse)
        else
          sum.concat([*opt.each].reverse)
        end
      end
      sum.reverse_each(&block)
    end

    def add_banner(to)  # :nodoc:
      list.each do |opt|
        if opt.respond_to?(:add_banner)
          opt.add_banner(to)
        end
      end
      to
    end

    def compsys(*args, &block)  # :nodoc:
      list.each do |opt|
        if opt.respond_to?(:compsys)
          opt.compsys(*args, &block)
        end
      end
    end
  end

  class CompletingHash < Hash
    include Completion

    def match(key)
      *values = fetch(key) {
        raise AmbiguousArgument, catch(:ambiguous) {return complete(key)}
      }
      return key, *values
    end
  end


  ArgumentStyle = {}
  NoArgument.each {|el| ArgumentStyle[el] = Switch::NoArgument}
  RequiredArgument.each {|el| ArgumentStyle[el] = Switch::RequiredArgument}
  OptionalArgument.each {|el| ArgumentStyle[el] = Switch::OptionalArgument}
  ArgumentStyle.freeze

  DefaultList = List.new
  DefaultList.short['-'] = Switch::NoArgument.new {}
  DefaultList.long[''] = Switch::NoArgument.new {throw :terminate}


  COMPSYS_HEADER = <<'XXX'      # :nodoc:

typeset -A opt_args
local context state line

_arguments -s -S \
XXX

  def compsys(to, name = File.basename($0)) # :nodoc:
    to << "#compdef #{name}\n"
    to << COMPSYS_HEADER
    visit(:compsys, {}, {}) {|o, d|
      to << %Q[  "#{o}[#{d.gsub(/[\"\[\]]/, '\\\\\&')}]" \\\n]
    }
    to << "  '*:file:_files' && return 0\n"
  end

  Officious = {}

  Officious['help'] = proc do |parser|
    Switch::NoArgument.new do |arg|
      puts parser.help
      exit
    end
  end

  Officious['*-completion-bash'] = proc do |parser|
    Switch::RequiredArgument.new do |arg|
      puts parser.candidate(arg)
      exit
    end
  end

  Officious['*-completion-zsh'] = proc do |parser|
    Switch::OptionalArgument.new do |arg|
      parser.compsys(STDOUT, arg)
      exit
    end
  end

  Officious['version'] = proc do |parser|
    Switch::OptionalArgument.new do |pkg|
      if pkg
        begin
          require 'optparse/version'
        rescue LoadError
        else
          show_version(*pkg.split(/,/)) or
            abort("#{parser.program_name}: no version found in package #{pkg}")
          exit
        end
      end
      v = parser.ver or abort("#{parser.program_name}: version unknown")
      puts v
      exit
    end
  end



  def self.with(*args, &block)
    opts = new(*args)
    #nodyna <instance_eval-1915> <IEV COMPLEX (block execution)>
    opts.instance_eval(&block)
    opts
  end

  def self.inc(arg, default = nil)
    case arg
    when Integer
      arg.nonzero?
    when nil
      default.to_i + 1
    end
  end
  def inc(*args)
    self.class.inc(*args)
  end

  def initialize(banner = nil, width = 32, indent = ' ' * 4)
    @stack = [DefaultList, List.new, List.new]
    @program_name = nil
    @banner = banner
    @summary_width = width
    @summary_indent = indent
    @default_argv = ARGV
    add_officious
    yield self if block_given?
  end

  def add_officious  # :nodoc:
    list = base()
    Officious.each do |opt, block|
      list.long[opt] ||= block.call(self)
    end
  end

  def terminate(arg = nil)
    self.class.terminate(arg)
  end
  def self.terminate(arg = nil)
    throw :terminate, arg
  end

  @stack = [DefaultList]
  def self.top() DefaultList end

  def accept(*args, &blk) top.accept(*args, &blk) end
  def self.accept(*args, &blk) top.accept(*args, &blk) end

  def reject(*args, &blk) top.reject(*args, &blk) end
  def self.reject(*args, &blk) top.reject(*args, &blk) end


  attr_writer :banner

  attr_writer :program_name

  attr_accessor :summary_width

  attr_accessor :summary_indent

  attr_accessor :default_argv

  def banner
    unless @banner
      @banner = "Usage: #{program_name} [options]"
      visit(:add_banner, @banner)
    end
    @banner
  end

  def program_name
    @program_name || File.basename($0, '.*')
  end

  alias set_banner banner=
  alias set_program_name program_name=
  alias set_summary_width summary_width=
  alias set_summary_indent summary_indent=

  attr_writer :version
  attr_writer :release

  def version
    @version || (defined?(::Version) && ::Version)
  end

  def release
    @release || (defined?(::Release) && ::Release) || (defined?(::RELEASE) && ::RELEASE)
  end

  def ver
    if v = version
      str = "#{program_name} #{[v].join('.')}"
      str << " (#{v})" if v = release
      str
    end
  end

  def warn(mesg = $!)
    super("#{program_name}: #{mesg}")
  end

  def abort(mesg = $!)
    super("#{program_name}: #{mesg}")
  end

  def top
    @stack[-1]
  end

  def base
    @stack[1]
  end

  def new
    @stack.push(List.new)
    if block_given?
      yield self
    else
      self
    end
  end

  def remove
    @stack.pop
  end

  def summarize(to = [], width = @summary_width, max = width - 1, indent = @summary_indent, &blk)
    blk ||= proc {|l| to << (l.index($/, -1) ? l : l + $/)}
    visit(:summarize, {}, {}, width, max, indent, &blk)
    to
  end

  def help; summarize("#{banner}".sub(/\n?\z/, "\n")) end
  alias to_s help

  def to_a; summarize("#{banner}".split(/^/)) end

  def notwice(obj, prv, msg)
    unless !prv or prv == obj
      raise(ArgumentError, "argument #{msg} given twice: #{obj}",
            ParseError.filter_backtrace(caller(2)))
    end
    obj
  end
  private :notwice

  SPLAT_PROC = proc {|*a| a.length <= 1 ? a.first : a} # :nodoc:
  def make_switch(opts, block = nil)
    short, long, nolong, style, pattern, conv, not_pattern, not_conv, not_style = [], [], []
    ldesc, sdesc, desc, arg = [], [], []
    default_style = Switch::NoArgument
    default_pattern = nil
    klass = nil
    q, a = nil

    opts.each do |o|
      next if search(:atype, o) do |pat, c|
        klass = notwice(o, klass, 'type')
        if not_style and not_style != Switch::NoArgument
          not_pattern, not_conv = pat, c
        else
          default_pattern, conv = pat, c
        end
      end

      if (!(String === o || Symbol === o)) and o.respond_to?(:match)
        pattern = notwice(o, pattern, 'pattern')
        if pattern.respond_to?(:convert)
          conv = pattern.method(:convert).to_proc
        else
          conv = SPLAT_PROC
        end
        next
      end

      case o
      when Proc, Method
        block = notwice(o, block, 'block')
      when Array, Hash
        case pattern
        when CompletingHash
        when nil
          pattern = CompletingHash.new
          conv = pattern.method(:convert).to_proc if pattern.respond_to?(:convert)
        else
          raise ArgumentError, "argument pattern given twice"
        end
        o.each {|pat, *v| pattern[pat] = v.fetch(0) {pat}}
      when Module
        raise ArgumentError, "unsupported argument type: #{o}", ParseError.filter_backtrace(caller(4))
      when *ArgumentStyle.keys
        style = notwice(ArgumentStyle[o], style, 'style')
      when /^--no-([^\[\]=\s]*)(.+)?/
        q, a = $1, $2
        o = notwice(a ? Object : TrueClass, klass, 'type')
        not_pattern, not_conv = search(:atype, o) unless not_style
        not_style = (not_style || default_style).guess(arg = a) if a
        default_style = Switch::NoArgument
        default_pattern, conv = search(:atype, FalseClass) unless default_pattern
        ldesc << "--no-#{q}"
        long << 'no-' + (q = q.downcase)
        nolong << q
      when /^--\[no-\]([^\[\]=\s]*)(.+)?/
        q, a = $1, $2
        o = notwice(a ? Object : TrueClass, klass, 'type')
        if a
          default_style = default_style.guess(arg = a)
          default_pattern, conv = search(:atype, o) unless default_pattern
        end
        ldesc << "--[no-]#{q}"
        long << (o = q.downcase)
        not_pattern, not_conv = search(:atype, FalseClass) unless not_style
        not_style = Switch::NoArgument
        nolong << 'no-' + o
      when /^--([^\[\]=\s]*)(.+)?/
        q, a = $1, $2
        if a
          o = notwice(NilClass, klass, 'type')
          default_style = default_style.guess(arg = a)
          default_pattern, conv = search(:atype, o) unless default_pattern
        end
        ldesc << "--#{q}"
        long << (o = q.downcase)
      when /^-(\[\^?\]?(?:[^\\\]]|\\.)*\])(.+)?/
        q, a = $1, $2
        o = notwice(Object, klass, 'type')
        if a
          default_style = default_style.guess(arg = a)
          default_pattern, conv = search(:atype, o) unless default_pattern
        end
        sdesc << "-#{q}"
        short << Regexp.new(q)
      when /^-(.)(.+)?/
        q, a = $1, $2
        if a
          o = notwice(NilClass, klass, 'type')
          default_style = default_style.guess(arg = a)
          default_pattern, conv = search(:atype, o) unless default_pattern
        end
        sdesc << "-#{q}"
        short << q
      when /^=/
        style = notwice(default_style.guess(arg = o), style, 'style')
        default_pattern, conv = search(:atype, Object) unless default_pattern
      else
        desc.push(o)
      end
    end

    default_pattern, conv = search(:atype, default_style.pattern) unless default_pattern
    if !(short.empty? and long.empty?)
      s = (style || default_style).new(pattern || default_pattern,
                                       conv, sdesc, ldesc, arg, desc, block)
    elsif !block
      if style or pattern
        raise ArgumentError, "no switch given", ParseError.filter_backtrace(caller)
      end
      s = desc
    else
      short << pattern
      s = (style || default_style).new(pattern,
                                       conv, nil, nil, arg, desc, block)
    end
    return s, short, long,
      (not_style.new(not_pattern, not_conv, sdesc, ldesc, nil, desc, block) if not_style),
      nolong
  end

  def define(*opts, &block)
    top.append(*(sw = make_switch(opts, block)))
    sw[0]
  end

  def on(*opts, &block)
    define(*opts, &block)
    self
  end
  alias def_option define

  def define_head(*opts, &block)
    top.prepend(*(sw = make_switch(opts, block)))
    sw[0]
  end

  def on_head(*opts, &block)
    define_head(*opts, &block)
    self
  end
  alias def_head_option define_head

  def define_tail(*opts, &block)
    base.append(*(sw = make_switch(opts, block)))
    sw[0]
  end

  def on_tail(*opts, &block)
    define_tail(*opts, &block)
    self
  end
  alias def_tail_option define_tail

  def separator(string)
    top.append(string, nil, nil)
  end

  def order(*argv, &block)
    argv = argv[0].dup if argv.size == 1 and Array === argv[0]
    order!(argv, &block)
  end

  def order!(argv = default_argv, &nonopt)
    parse_in_order(argv, &nonopt)
  end

  def parse_in_order(argv = default_argv, setter = nil, &nonopt)  # :nodoc:
    opt, arg, val, rest = nil
    nonopt ||= proc {|a| throw :terminate, a}
    argv.unshift(arg) if arg = catch(:terminate) {
      while arg = argv.shift
        case arg
        when /\A--([^=]*)(?:=(.*))?/m
          opt, rest = $1, $2
          begin
            sw, = complete(:long, opt, true)
          rescue ParseError
            raise $!.set_option(arg, true)
          end
          begin
            opt, cb, val = sw.parse(rest, argv) {|*exc| raise(*exc)}
            val = cb.call(val) if cb
            setter.call(sw.switch_name, val) if setter
          rescue ParseError
            raise $!.set_option(arg, rest)
          end

        when /\A-(.)((=).*|.+)?/m
          opt, has_arg, eq, val, rest = $1, $3, $3, $2, $2
          begin
            sw, = search(:short, opt)
            unless sw
              begin
                sw, = complete(:short, opt)
                val = arg.sub(/\A-/, '')
                has_arg = true
              rescue InvalidOption
                sw, = complete(:long, opt)
                eq ||= !rest
              end
            end
          rescue ParseError
            raise $!.set_option(arg, true)
          end
          begin
            opt, cb, val = sw.parse(val, argv) {|*exc| raise(*exc) if eq}
            raise InvalidOption, arg if has_arg and !eq and arg == "-#{opt}"
            argv.unshift(opt) if opt and (!rest or (opt = opt.sub(/\A-*/, '-')) != '-')
            val = cb.call(val) if cb
            setter.call(sw.switch_name, val) if setter
          rescue ParseError
            raise $!.set_option(arg, arg.length > 2)
          end

        else
          catch(:prune) do
            visit(:each_option) do |sw0|
              sw = sw0
              sw.block.call(arg) if Switch === sw and sw.match_nonswitch?(arg)
            end
            nonopt.call(arg)
          end
        end
      end

      nil
    }

    visit(:search, :short, nil) {|sw| sw.block.call(*argv) if !sw.pattern}

    argv
  end
  private :parse_in_order

  def permute(*argv)
    argv = argv[0].dup if argv.size == 1 and Array === argv[0]
    permute!(argv)
  end

  def permute!(argv = default_argv)
    nonopts = []
    order!(argv, &nonopts.method(:<<))
    argv[0, 0] = nonopts
    argv
  end

  def parse(*argv)
    argv = argv[0].dup if argv.size == 1 and Array === argv[0]
    parse!(argv)
  end

  def parse!(argv = default_argv)
    if ENV.include?('POSIXLY_CORRECT')
      order!(argv)
    else
      permute!(argv)
    end
  end

  def getopts(*args)
    argv = Array === args.first ? args.shift : default_argv
    single_options, *long_options = *args

    result = {}

    single_options.scan(/(.)(:)?/) do |opt, val|
      if val
        result[opt] = nil
        define("-#{opt} VAL")
      else
        result[opt] = false
        define("-#{opt}")
      end
    end if single_options

    long_options.each do |arg|
      arg, desc = arg.split(';', 2)
      opt, val = arg.split(':', 2)
      if val
        result[opt] = val.empty? ? nil : val
        define("--#{opt}=#{result[opt] || "VAL"}", *[desc].compact)
      else
        result[opt] = false
        define("--#{opt}", *[desc].compact)
      end
    end

    parse_in_order(argv, result.method(:[]=))
    result
  end

  def self.getopts(*args)
    new.getopts(*args)
  end

  def visit(id, *args, &block)
    @stack.reverse_each do |el|
      #nodyna <send-1916> <SD MODERATE (change-prone variables)>
      el.send(id, *args, &block)
    end
    nil
  end
  private :visit

  def search(id, key)
    block_given = block_given?
    visit(:search, id, key) do |k|
      return block_given ? yield(k) : k
    end
  end
  private :search

  def complete(typ, opt, icase = false, *pat)
    if pat.empty?
      search(typ, opt) {|sw| return [sw, opt]} # exact match or...
    end
    raise AmbiguousOption, catch(:ambiguous) {
      visit(:complete, typ, opt, icase, *pat) {|o, *sw| return sw}
      raise InvalidOption, opt
    }
  end
  private :complete

  def candidate(word)
    list = []
    case word
    when /\A--/
      word, arg = word.split(/=/, 2)
      argpat = Completion.regexp(arg, false) if arg and !arg.empty?
      long = true
    when /\A-(!-)/
      short = true
    when /\A-/
      long = short = true
    end
    pat = Completion.regexp(word, true)
    visit(:each_option) do |opt|
      next unless Switch === opt
      opts = (long ? opt.long : []) + (short ? opt.short : [])
      opts = Completion.candidate(word, true, pat, &opts.method(:each)).map(&:first) if pat
      if /\A=/ =~ opt.arg
        opts.map! {|sw| sw + "="}
        if arg and CompletingHash === opt.pattern
          if opts = opt.pattern.candidate(arg, false, argpat)
            opts.map!(&:last)
          end
        end
      end
      list.concat(opts)
    end
    list
  end

  def load(filename = nil)
    begin
      filename ||= File.expand_path(File.basename($0, '.*'), '~/.options')
    rescue
      return false
    end
    begin
      parse(*IO.readlines(filename).each {|s| s.chomp!})
      true
    rescue Errno::ENOENT, Errno::ENOTDIR
      false
    end
  end

  def environment(env = File.basename($0, '.*'))
    env = ENV[env] || ENV[env.upcase] or return
    require 'shellwords'
    parse(*Shellwords.shellwords(env))
  end


  accept(Object) {|s,|s or s.nil?}

  accept(NilClass) {|s,|s}

  accept(String, /.+/m) {|s,*|s}

  decimal = '\d+(?:_\d+)*'
  binary = 'b[01]+(?:_[01]+)*'
  hex = 'x[\da-f]+(?:_[\da-f]+)*'
  octal = "0(?:[0-7]+(?:_[0-7]+)*|#{binary}|#{hex})?"
  integer = "#{octal}|#{decimal}"

  accept(Integer, %r"\A[-+]?(?:#{integer})\z"io) {|s,|
    begin
      Integer(s)
    rescue ArgumentError
      raise OptionParser::InvalidArgument, s
    end if s
  }

  float = "(?:#{decimal}(?:\\.(?:#{decimal})?)?|\\.#{decimal})(?:E[-+]?#{decimal})?"
  floatpat = %r"\A[-+]?#{float}\z"io
  accept(Float, floatpat) {|s,| s.to_f if s}

  real = "[-+]?(?:#{octal}|#{float})"
  accept(Numeric, /\A(#{real})(?:\/(#{real}))?\z/io) {|s, d, n|
    if n
      Rational(d, n)
    elsif s
      #nodyna <eval-1917> <EV COMPLEX (change-prone variables)>
      eval(s)
    end
  }

  DecimalInteger = /\A[-+]?#{decimal}\z/io
  accept(DecimalInteger, DecimalInteger) {|s,|
    begin
      Integer(s)
    rescue ArgumentError
      raise OptionParser::InvalidArgument, s
    end if s
  }

  OctalInteger = /\A[-+]?(?:[0-7]+(?:_[0-7]+)*|0(?:#{binary}|#{hex}))\z/io
  accept(OctalInteger, OctalInteger) {|s,|
    begin
      Integer(s, 8)
    rescue ArgumentError
      raise OptionParser::InvalidArgument, s
    end if s
  }

  DecimalNumeric = floatpat     # decimal integer is allowed as float also.
  accept(DecimalNumeric, floatpat) {|s,|
    begin
      #nodyna <eval-1918> <EV COMPLEX (change-prone variables)>
      eval(s)
    rescue SyntaxError
      raise OptionParser::InvalidArgument, s
    end if s
  }

  yesno = CompletingHash.new
  %w[- no false].each {|el| yesno[el] = false}
  %w[+ yes true].each {|el| yesno[el] = true}
  yesno['nil'] = false          # should be nil?
  accept(TrueClass, yesno) {|arg, val| val == nil or val}
  accept(FalseClass, yesno) {|arg, val| val != nil and val}

  accept(Array) do |s,|
    if s
      s = s.split(',').collect {|ss| ss unless ss.empty?}
    end
    s
  end

  accept(Regexp, %r"\A/((?:\\.|[^\\])*)/([[:alpha:]]+)?\z|.*") do |all, s, o|
    f = 0
    if o
      f |= Regexp::IGNORECASE if /i/ =~ o
      f |= Regexp::MULTILINE if /m/ =~ o
      f |= Regexp::EXTENDED if /x/ =~ o
      k = o.delete("imx")
      k = nil if k.empty?
    end
    Regexp.new(s || all, f, k)
  end


  class ParseError < RuntimeError
    Reason = 'parse error'.freeze

    def initialize(*args)
      @args = args
      @reason = nil
    end

    attr_reader :args
    attr_writer :reason

    def recover(argv)
      argv[0, 0] = @args
      argv
    end

    def self.filter_backtrace(array)
      unless $DEBUG
        array.delete_if(&%r"\A#{Regexp.quote(__FILE__)}:"o.method(:=~))
      end
      array
    end

    def set_backtrace(array)
      super(self.class.filter_backtrace(array))
    end

    def set_option(opt, eq)
      if eq
        @args[0] = opt
      else
        @args.unshift(opt)
      end
      self
    end

    def reason
      @reason || self.class::Reason
    end

    def inspect
      "#<#{self.class}: #{args.join(' ')}>"
    end

    def message
      reason + ': ' + args.join(' ')
    end

    alias to_s message
  end

  class AmbiguousOption < ParseError
    #nodyna <const_set-1919> <CS TRIVIAL (static values)>
    const_set(:Reason, 'ambiguous option'.freeze)
  end

  class NeedlessArgument < ParseError
    #nodyna <const_set-1920> <CS TRIVIAL (static values)>
    const_set(:Reason, 'needless argument'.freeze)
  end

  class MissingArgument < ParseError
    #nodyna <const_set-1921> <CS TRIVIAL (static values)>
    const_set(:Reason, 'missing argument'.freeze)
  end

  class InvalidOption < ParseError
    #nodyna <const_set-1922> <CS TRIVIAL (static values)>
    const_set(:Reason, 'invalid option'.freeze)
  end

  class InvalidArgument < ParseError
    #nodyna <const_set-1923> <CS TRIVIAL (static values)>
    const_set(:Reason, 'invalid argument'.freeze)
  end

  class AmbiguousArgument < InvalidArgument
    #nodyna <const_set-1924> <CS TRIVIAL (static values)>
    const_set(:Reason, 'ambiguous argument'.freeze)
  end


  module Arguable

    def options=(opt)
      unless @optparse = opt
        class << self
          undef_method(:options)
          undef_method(:options=)
        end
      end
    end

    def options
      @optparse ||= OptionParser.new
      @optparse.default_argv = self
      block_given? or return @optparse
      begin
        yield @optparse
      rescue ParseError
        @optparse.warn $!
        nil
      end
    end

    def order!(&blk) options.order!(self, &blk) end

    def permute!() options.permute!(self) end

    def parse!() options.parse!(self) end

    def getopts(*args)
      options.getopts(self, *args)
    end

    def self.extend_object(obj)
      super
      #nodyna <instance_eval-1925> <IEV COMPLEX (private access)>
      obj.instance_eval {@optparse = nil}
    end
    def initialize(*args)
      super
      @optparse = nil
    end
  end

  module Acceptables
    #nodyna <const_set-1926> <CS TRIVIAL (static values)>
    const_set(:DecimalInteger, OptionParser::DecimalInteger)
    #nodyna <const_set-1927> <CS TRIVIAL (static values)>
    const_set(:OctalInteger, OptionParser::OctalInteger)
    #nodyna <const_set-1928> <CS TRIVIAL (static values)>
    const_set(:DecimalNumeric, OptionParser::DecimalNumeric)
  end
end

ARGV.extend(OptionParser::Arguable)

OptParse = OptionParser
