
require 'rbconfig'
require 'fileutils'
require 'shellwords'

class String
  def quote
    /\s/ =~ self ? "\"#{self}\"" : "#{self}"
  end

  def unspace
    gsub(/\s/, '\\\\\\&')
  end

  def tr_cpp
    strip.upcase.tr_s("^A-Z0-9_*", "_").tr_s("*", "P")
  end

  def funcall_style
    /\)\z/ =~ self ? dup : "#{self}()"
  end

  def sans_arguments
    self[/\A[^()]+/]
  end
end

class Array
  def quote
    map {|s| s.quote}
  end
end

module MakeMakefile


  CONFIG = RbConfig::MAKEFILE_CONFIG
  ORIG_LIBPATH = ENV['LIB']


  C_EXT = %w[c m]


  CXX_EXT = %w[cc mm cxx cpp]
  unless File.exist?(File.join(*File.split(__FILE__).tap {|d, b| b.swapcase}))
    CXX_EXT.concat(%w[C])
  end


  SRC_EXT = C_EXT + CXX_EXT


  HDR_EXT = %w[h hpp]
  $static = nil
  $config_h = '$(arch_hdrdir)/ruby/config.h'
  $default_static = $static

  unless defined? $configure_args
    $configure_args = {}
    args = CONFIG["configure_args"]
    if ENV["CONFIGURE_ARGS"]
      args << " " << ENV["CONFIGURE_ARGS"]
    end
    for arg in Shellwords::shellwords(args)
      arg, val = arg.split('=', 2)
      next unless arg
      arg.tr!('_', '-')
      if arg.sub!(/^(?!--)/, '--')
        val or next
        arg.downcase!
      end
      next if /^--(?:top|topsrc|src|cur)dir$/ =~ arg
      $configure_args[arg] = val || true
    end
    for arg in ARGV
      arg, val = arg.split('=', 2)
      next unless arg
      arg.tr!('_', '-')
      if arg.sub!(/^(?!--)/, '--')
        val or next
        arg.downcase!
      end
      $configure_args[arg] = val || true
    end
  end

  $libdir = CONFIG["libdir"]
  $rubylibdir = CONFIG["rubylibdir"]
  $archdir = CONFIG["archdir"]
  $sitedir = CONFIG["sitedir"]
  $sitelibdir = CONFIG["sitelibdir"]
  $sitearchdir = CONFIG["sitearchdir"]
  $vendordir = CONFIG["vendordir"]
  $vendorlibdir = CONFIG["vendorlibdir"]
  $vendorarchdir = CONFIG["vendorarchdir"]

  $mswin = /mswin/ =~ RUBY_PLATFORM
  $bccwin = /bccwin/ =~ RUBY_PLATFORM
  $mingw = /mingw/ =~ RUBY_PLATFORM
  $cygwin = /cygwin/ =~ RUBY_PLATFORM
  $netbsd = /netbsd/ =~ RUBY_PLATFORM
  $os2 = /os2/ =~ RUBY_PLATFORM
  $beos = /beos/ =~ RUBY_PLATFORM
  $haiku = /haiku/ =~ RUBY_PLATFORM
  $solaris = /solaris/ =~ RUBY_PLATFORM
  $universal = /universal/ =~ RUBY_PLATFORM
  $dest_prefix_pattern = (File::PATH_SEPARATOR == ';' ? /\A([[:alpha:]]:)?/ : /\A/)


  def config_string(key, config = CONFIG)
    s = config[key] and !s.empty? and block_given? ? yield(s) : s
  end
  module_function :config_string

  def dir_re(dir)
    Regexp.new('\$(?:\('+dir+'\)|\{'+dir+'\})(?:\$(?:\(target_prefix\)|\{target_prefix\}))?')
  end
  module_function :dir_re

  def relative_from(path, base)
    dir = File.join(path, "")
    if File.expand_path(dir) == File.expand_path(dir, base)
      path
    else
      File.join(base, path)
    end
  end

  INSTALL_DIRS = [
    [dir_re('commondir'), "$(RUBYCOMMONDIR)"],
    [dir_re('sitedir'), "$(RUBYCOMMONDIR)"],
    [dir_re('vendordir'), "$(RUBYCOMMONDIR)"],
    [dir_re('rubylibdir'), "$(RUBYLIBDIR)"],
    [dir_re('archdir'), "$(RUBYARCHDIR)"],
    [dir_re('sitelibdir'), "$(RUBYLIBDIR)"],
    [dir_re('vendorlibdir'), "$(RUBYLIBDIR)"],
    [dir_re('sitearchdir'), "$(RUBYARCHDIR)"],
    [dir_re('vendorarchdir'), "$(RUBYARCHDIR)"],
    [dir_re('rubyhdrdir'), "$(RUBYHDRDIR)"],
    [dir_re('sitehdrdir'), "$(SITEHDRDIR)"],
    [dir_re('vendorhdrdir'), "$(VENDORHDRDIR)"],
    [dir_re('bindir'), "$(BINDIR)"],
  ]

  def install_dirs(target_prefix = nil)
    if $extout
      dirs = [
        ['BINDIR',        '$(extout)/bin'],
        ['RUBYCOMMONDIR', '$(extout)/common'],
        ['RUBYLIBDIR',    '$(RUBYCOMMONDIR)$(target_prefix)'],
        ['RUBYARCHDIR',   '$(extout)/$(arch)$(target_prefix)'],
        ['HDRDIR',        '$(extout)/include/ruby$(target_prefix)'],
        ['ARCHHDRDIR',    '$(extout)/include/$(arch)/ruby$(target_prefix)'],
        ['extout',        "#$extout"],
        ['extout_prefix', "#$extout_prefix"],
      ]
    elsif $extmk
      dirs = [
        ['BINDIR',        '$(bindir)'],
        ['RUBYCOMMONDIR', '$(rubylibdir)'],
        ['RUBYLIBDIR',    '$(rubylibdir)$(target_prefix)'],
        ['RUBYARCHDIR',   '$(archdir)$(target_prefix)'],
        ['HDRDIR',        '$(rubyhdrdir)/ruby$(target_prefix)'],
        ['ARCHHDRDIR',    '$(rubyhdrdir)/$(arch)/ruby$(target_prefix)'],
      ]
    elsif $configure_args.has_key?('--vendor')
      dirs = [
        ['BINDIR',        '$(bindir)'],
        ['RUBYCOMMONDIR', '$(vendordir)$(target_prefix)'],
        ['RUBYLIBDIR',    '$(vendorlibdir)$(target_prefix)'],
        ['RUBYARCHDIR',   '$(vendorarchdir)$(target_prefix)'],
        ['HDRDIR',        '$(rubyhdrdir)/ruby$(target_prefix)'],
        ['ARCHHDRDIR',    '$(rubyhdrdir)/$(arch)/ruby$(target_prefix)'],
      ]
    else
      dirs = [
        ['BINDIR',        '$(bindir)'],
        ['RUBYCOMMONDIR', '$(sitedir)$(target_prefix)'],
        ['RUBYLIBDIR',    '$(sitelibdir)$(target_prefix)'],
        ['RUBYARCHDIR',   '$(sitearchdir)$(target_prefix)'],
        ['HDRDIR',        '$(rubyhdrdir)/ruby$(target_prefix)'],
        ['ARCHHDRDIR',    '$(rubyhdrdir)/$(arch)/ruby$(target_prefix)'],
      ]
    end
    dirs << ['target_prefix', (target_prefix ? "/#{target_prefix}" : "")]
    dirs
  end

  def map_dir(dir, map = nil)
    map ||= INSTALL_DIRS
    map.inject(dir) {|d, (orig, new)| d.gsub(orig, new)}
  end

  topdir = File.dirname(File.dirname(__FILE__))
  path = File.expand_path($0)
  until (dir = File.dirname(path)) == path
    if File.identical?(dir, topdir)
      $extmk = true if %r"\A(?:ext|enc|tool|test)\z" =~ File.basename(path)
      break
    end
    path = dir
  end
  $extmk ||= false
  if not $extmk and File.exist?(($hdrdir = RbConfig::CONFIG["rubyhdrdir"]) + "/ruby/ruby.h")
    $topdir = $hdrdir
    $top_srcdir = $hdrdir
    $arch_hdrdir = RbConfig::CONFIG["rubyarchhdrdir"]
  elsif File.exist?(($hdrdir = ($top_srcdir ||= topdir) + "/include")  + "/ruby.h")
    $topdir ||= RbConfig::CONFIG["topdir"]
    $arch_hdrdir = "$(extout)/include/$(arch)"
  else
    abort "mkmf.rb can't find header files for ruby at #{$hdrdir}/ruby.h"
  end

  CONFTEST = "conftest".freeze
  CONFTEST_C = "#{CONFTEST}.c"

  OUTFLAG = CONFIG['OUTFLAG']
  COUTFLAG = CONFIG['COUTFLAG']
  CPPOUTFILE = config_string('CPPOUTFILE') {|str| str.sub(/\bconftest\b/, CONFTEST)}

  def rm_f(*files)
    opt = (Hash === files.last ? [files.pop] : [])
    FileUtils.rm_f(Dir[*files.flatten], *opt)
  end
  module_function :rm_f

  def rm_rf(*files)
    opt = (Hash === files.last ? [files.pop] : [])
    FileUtils.rm_rf(Dir[*files.flatten], *opt)
  end
  module_function :rm_rf

  def modified?(target, times)
    (t = File.mtime(target)) rescue return nil
    Array === times or times = [times]
    t if times.all? {|n| n <= t}
  end

  def split_libs(*strs)
    strs.map {|s| s.split(/\s+(?=-|\z)/)}.flatten
  end

  def merge_libs(*libs)
    libs.inject([]) do |x, y|
      y = y.inject([]) {|ary, e| ary.last == e ? ary : ary << e}
      y.each_with_index do |v, yi|
        if xi = x.rindex(v)
          x[(xi+1)..-1] = merge_libs(y[(yi+1)..-1], x[(xi+1)..-1])
          x[xi, 0] = y[0...yi]
          break
        end
      end and x.concat(y)
      x
    end
  end

  module Logging
    @log = nil
    @logfile = 'mkmf.log'
    @orgerr = $stderr.dup
    @orgout = $stdout.dup
    @postpone = 0
    @quiet = $extmk

    def self::log_open
      @log ||= File::open(@logfile, 'wb')
      @log.sync = true
    end

    def self::log_opened?
      @log and not @log.closed?
    end

    def self::open
      log_open
      $stderr.reopen(@log)
      $stdout.reopen(@log)
      yield
    ensure
      $stderr.reopen(@orgerr)
      $stdout.reopen(@orgout)
    end

    def self::message(*s)
      log_open
      @log.printf(*s)
    end

    def self::logfile file
      @logfile = file
      log_close
    end

    def self::log_close
      if @log and not @log.closed?
        @log.flush
        @log.close
        @log = nil
      end
    end

    def self::postpone
      tmplog = "mkmftmp#{@postpone += 1}.log"
      open do
        log, *save = @log, @logfile, @orgout, @orgerr
        @log, @logfile, @orgout, @orgerr = nil, tmplog, log, log
        begin
          log.print(open {yield @log})
        ensure
          @log.close if @log and not @log.closed?
          File::open(tmplog) {|t| FileUtils.copy_stream(t, log)} if File.exist?(tmplog)
          @log, @logfile, @orgout, @orgerr = log, *save
          @postpone -= 1
          MakeMakefile.rm_f tmplog
        end
      end
    end

    class << self
      attr_accessor :quiet
    end
  end

  def libpath_env
    if libpathenv = config_string("LIBPATHENV")
      pathenv = ENV[libpathenv]
      libpath = RbConfig.expand($DEFLIBPATH.join(File::PATH_SEPARATOR))
      {libpathenv => [libpath, pathenv].compact.join(File::PATH_SEPARATOR)}
    else
      {}
    end
  end

  def xsystem command, opts = nil
    varpat = /\$\((\w+)\)|\$\{(\w+)\}/
    if varpat =~ command
      vars = Hash.new {|h, k| h[k] = ENV[k]}
      command = command.dup
      nil while command.gsub!(varpat) {vars[$1||$2]}
    end
    Logging::open do
      puts command.quote
      if opts and opts[:werror]
        result = nil
        Logging.postpone do |log|
          result = (system(libpath_env, command) and File.zero?(log.path))
          ""
        end
        result
      else
        system(libpath_env, command)
      end
    end
  end

  def xpopen command, *mode, &block
    Logging::open do
      case mode[0]
      when nil, /^r/
        puts "#{command} |"
      else
        puts "| #{command}"
      end
      IO.popen(libpath_env, command, *mode, &block)
    end
  end

  def log_src(src, heading="checked program was")
    src = src.split(/^/)
    fmt = "%#{src.size.to_s.size}d: %s"
    Logging::message <<"EOM"
/* begin */
EOM
    src.each_with_index {|line, no| Logging::message fmt, no+1, line}
    Logging::message <<"EOM"
/* end */

EOM
  end

  def create_tmpsrc(src)
    src = "#{COMMON_HEADERS}\n#{src}"
    src = yield(src) if block_given?
    src.gsub!(/[ \t]+$/, '')
    src.gsub!(/\A\n+|^\n+$/, '')
    src.sub!(/[^\n]\z/, "\\&\n")
    count = 0
    begin
      open(CONFTEST_C, "wb") do |cfile|
        cfile.print src
      end
    rescue Errno::EACCES
      if (count += 1) < 5
        sleep 0.2
        retry
      end
    end
    src
  end

  def have_devel?
    unless defined? $have_devel
      $have_devel = true
      $have_devel = try_link(MAIN_DOES_NOTHING)
    end
    $have_devel
  end

  def try_do(src, command, *opts, &b)
    unless have_devel?
      raise <<MSG
The compiler failed to generate an executable file.
You have to install development tools first.
MSG
    end
    begin
      src = create_tmpsrc(src, &b)
      xsystem(command, *opts)
    ensure
      log_src(src)
      MakeMakefile.rm_rf "#{CONFTEST}.dSYM"
    end
  end

  def link_command(ldflags, opt="", libpath=$LIBPATH|$DEFLIBPATH)
    librubyarg = $extmk ? $LIBRUBYARG_STATIC : "$(LIBRUBYARG)"
    conf = RbConfig::CONFIG.merge('hdrdir' => $hdrdir.quote,
                                  'src' => "#{CONFTEST_C}",
                                  'arch_hdrdir' => $arch_hdrdir.quote,
                                  'top_srcdir' => $top_srcdir.quote,
                                  'INCFLAGS' => "#$INCFLAGS",
                                  'CPPFLAGS' => "#$CPPFLAGS",
                                  'CFLAGS' => "#$CFLAGS",
                                  'ARCH_FLAG' => "#$ARCH_FLAG",
                                  'LDFLAGS' => "#$LDFLAGS #{ldflags}",
                                  'LOCAL_LIBS' => "#$LOCAL_LIBS #$libs",
                                  'LIBS' => "#{librubyarg} #{opt} #$LIBS")
    conf['LIBPATH'] = libpathflag(libpath.map {|s| RbConfig::expand(s.dup, conf)})
    RbConfig::expand(TRY_LINK.dup, conf)
  end

  def cc_command(opt="")
    conf = RbConfig::CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote,
                                  'arch_hdrdir' => $arch_hdrdir.quote,
                                  'top_srcdir' => $top_srcdir.quote)
    RbConfig::expand("$(CC) #$INCFLAGS #$CPPFLAGS #$CFLAGS #$ARCH_FLAG #{opt} -c #{CONFTEST_C}",
                     conf)
  end

  def cpp_command(outfile, opt="")
    conf = RbConfig::CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote,
                                  'arch_hdrdir' => $arch_hdrdir.quote,
                                  'top_srcdir' => $top_srcdir.quote)
    if $universal and (arch_flag = conf['ARCH_FLAG']) and !arch_flag.empty?
      conf['ARCH_FLAG'] = arch_flag.gsub(/(?:\G|\s)-arch\s+\S+/, '')
    end
    RbConfig::expand("$(CPP) #$INCFLAGS #$CPPFLAGS #$CFLAGS #{opt} #{CONFTEST_C} #{outfile}",
                     conf)
  end

  def libpathflag(libpath=$LIBPATH|$DEFLIBPATH)
    libpath.map{|x|
      case x
      when "$(topdir)", /\A\./
        LIBPATHFLAG
      else
        LIBPATHFLAG+RPATHFLAG
      end % x.quote
    }.join
  end

  def with_werror(opt, opts = nil)
    if opts
      if opts[:werror] and config_string("WERRORFLAG") {|flag| opt = opt ? "#{opt} #{flag}" : flag}
        (opts = opts.dup).delete(:werror)
      end
      yield(opt, opts)
    else
      yield(opt)
    end
  end

  def try_link0(src, opt="", *opts, &b) # :nodoc:
    cmd = link_command("", opt)
    if $universal
      require 'tmpdir'
      Dir.mktmpdir("mkmf_", oldtmpdir = ENV["TMPDIR"]) do |tmpdir|
        begin
          ENV["TMPDIR"] = tmpdir
          try_do(src, cmd, *opts, &b)
        ensure
          ENV["TMPDIR"] = oldtmpdir
        end
      end
    else
      try_do(src, cmd, *opts, &b)
    end and File.executable?(CONFTEST+$EXEEXT)
  end

  def try_link(src, opt="", *opts, &b)
    try_link0(src, opt, *opts, &b)
  ensure
    MakeMakefile.rm_f "#{CONFTEST}*", "c0x32*"
  end

  def try_compile(src, opt="", *opts, &b)
    with_werror(opt, *opts) {|_opt, *_opts| try_do(src, cc_command(_opt), *_opts, &b)} and
      File.file?("#{CONFTEST}.#{$OBJEXT}")
  ensure
    MakeMakefile.rm_f "#{CONFTEST}*"
  end

  def try_cpp(src, opt="", *opts, &b)
    try_do(src, cpp_command(CPPOUTFILE, opt), *opts, &b) and
      File.file?("#{CONFTEST}.i")
  ensure
    MakeMakefile.rm_f "#{CONFTEST}*"
  end

  alias_method :try_header, (config_string('try_header') || :try_cpp)

  def cpp_include(header)
    if header
      header = [header] unless header.kind_of? Array
      header.map {|h| String === h ? "#include <#{h}>\n" : h}.join
    else
      ""
    end
  end

  def with_cppflags(flags)
    cppflags = $CPPFLAGS
    $CPPFLAGS = flags
    ret = yield
  ensure
    $CPPFLAGS = cppflags unless ret
  end

  def try_cppflags(flags)
    try_header(MAIN_DOES_NOTHING, flags)
  end

  def with_cflags(flags)
    cflags = $CFLAGS
    $CFLAGS = flags
    ret = yield
  ensure
    $CFLAGS = cflags unless ret
  end

  def try_cflags(flags)
    try_compile(MAIN_DOES_NOTHING, flags)
  end

  def with_ldflags(flags)
    ldflags = $LDFLAGS
    $LDFLAGS = flags
    ret = yield
  ensure
    $LDFLAGS = ldflags unless ret
  end

  def try_ldflags(flags)
    try_link(MAIN_DOES_NOTHING, flags)
  end

  def try_static_assert(expr, headers = nil, opt = "", &b)
    headers = cpp_include(headers)
    try_compile(<<SRC, opt, &b)
/*top*/
int conftest_const[(#{expr}) ? 1 : -1];
SRC
  end

  def try_constant(const, headers = nil, opt = "", &b)
    includes = cpp_include(headers)
    neg = try_static_assert("#{const} < 0", headers, opt)
    if CROSS_COMPILING
      if neg
        const = "-(#{const})"
      elsif try_static_assert("#{const} > 0", headers, opt)
      elsif try_static_assert("#{const} == 0", headers, opt)
        return 0
      else
        return nil
      end
      upper = 1
      until try_static_assert("#{const} <= #{upper}", headers, opt)
        lower = upper
        upper <<= 1
      end
      return nil unless lower
      while upper > lower + 1
        mid = (upper + lower) / 2
        if try_static_assert("#{const} > #{mid}", headers, opt)
          lower = mid
        else
          upper = mid
        end
      end
      upper = -upper if neg
      return upper
    else
      src = %{#{includes}
/*top*/
typedef#{neg ? '' : ' unsigned'}
LONG_LONG
long
conftest_type;
conftest_type conftest_const = (conftest_type)(#{const});
int main() {printf("%"PRI_CONFTEST_PREFIX"#{neg ? 'd' : 'u'}\\n", conftest_const); return 0;}
}
      begin
        if try_link0(src, opt, &b)
          xpopen("./#{CONFTEST}") do |f|
            return Integer(f.gets)
          end
        end
      ensure
        MakeMakefile.rm_f "#{CONFTEST}*"
      end
    end
    nil
  end

  def try_func(func, libs, headers = nil, opt = "", &b)
    headers = cpp_include(headers)
    case func
    when /^&/
      decltype = proc {|x|"const volatile void *#{x}"}
    when /\)$/
      call = func
    else
      call = "#{func}()"
      decltype = proc {|x| "void ((*#{x})())"}
    end
    if opt and !opt.empty?
      [[:to_str], [:join, " "], [:to_s]].each do |meth, *args|
        if opt.respond_to?(meth)
          #nodyna <send-2223> <SD MODERATE (array)>
          break opt = opt.send(meth, *args)
        end
      end
      opt = "#{opt} #{libs}"
    else
      opt = libs
    end
    decltype && try_link(<<"SRC", opt, &b) or
/*top*/
extern int t(void);
int t(void) { #{decltype["volatile p"]}; p = (#{decltype[]})#{func}; return 0; }
SRC
    call && try_link(<<"SRC", opt, &b)
/*top*/
extern int t(void);
int t(void) { #{call}; return 0; }
SRC
  end

  def try_var(var, headers = nil, opt = "", &b)
    headers = cpp_include(headers)
    try_compile(<<"SRC", opt, &b)
/*top*/
extern int t(void);
int t(void) { const volatile void *volatile p; p = &(&#{var})[0]; return 0; }
SRC
  end

  def egrep_cpp(pat, src, opt = "", &b)
    src = create_tmpsrc(src, &b)
    xpopen(cpp_command('', opt)) do |f|
      if Regexp === pat
        puts("    ruby -ne 'print if #{pat.inspect}'")
        f.grep(pat) {|l|
          puts "#{f.lineno}: #{l}"
          return true
        }
        false
      else
        puts("    egrep '#{pat}'")
        begin
          stdin = $stdin.dup
          $stdin.reopen(f)
          system("egrep", pat)
        ensure
          $stdin.reopen(stdin)
        end
      end
    end
  ensure
    MakeMakefile.rm_f "#{CONFTEST}*"
    log_src(src)
  end

  def macro_defined?(macro, src, opt = "", &b)
    src = src.sub(/[^\n]\z/, "\\&\n")
    try_compile(src + <<"SRC", opt, &b)
/*top*/
|:/ === #{macro} undefined === /:|
SRC
  end

  def try_run(src, opt = "", &b)
    raise "cannot run test program while cross compiling" if CROSS_COMPILING
    if try_link0(src, opt, &b)
      xsystem("./#{CONFTEST}")
    else
      nil
    end
  ensure
    MakeMakefile.rm_f "#{CONFTEST}*"
  end

  def install_files(mfile, ifiles, map = nil, srcprefix = nil)
    ifiles or return
    ifiles.empty? and return
    srcprefix ||= "$(srcdir)/#{srcprefix}".chomp('/')
    RbConfig::expand(srcdir = srcprefix.dup)
    dirs = []
    path = Hash.new {|h, i| h[i] = dirs.push([i])[-1]}
    ifiles.each do |files, dir, prefix|
      dir = map_dir(dir, map)
      prefix &&= %r|\A#{Regexp.quote(prefix)}/?|
      if /\A\.\// =~ files
        files = files[2..-1]
        len = nil
      else
        files = File.join(srcdir, files)
        len = srcdir.size
      end
      f = nil
      Dir.glob(files) do |fx|
        f = fx
        f[0..len] = "" if len
        case File.basename(f)
        when *$NONINSTALLFILES
          next
        end
        d = File.dirname(f)
        d.sub!(prefix, "") if prefix
        d = (d.empty? || d == ".") ? dir : File.join(dir, d)
        f = File.join(srcprefix, f) if len
        path[d] << f
      end
      unless len or f
        d = File.dirname(files)
        d.sub!(prefix, "") if prefix
        d = (d.empty? || d == ".") ? dir : File.join(dir, d)
        path[d] << files
      end
    end
    dirs
  end

  def install_rb(mfile, dest, srcdir = nil)
    install_files(mfile, [["lib/**/*.rb", dest, "lib"]], nil, srcdir)
  end

  def append_library(libs, lib) # :no-doc:
    format(LIBARG, lib) + " " + libs
  end

  def message(*s)
    unless Logging.quiet and not $VERBOSE
      printf(*s)
      $stdout.flush
    end
  end

  def checking_for(m, fmt = nil)
    f = caller[0][/in `([^<].*)'$/, 1] and f << ": " #` for vim #'
    m = "checking #{/\Acheck/ =~ f ? '' : 'for '}#{m}... "
    message "%s", m
    a = r = nil
    Logging::postpone do
      r = yield
      a = (fmt ? "#{fmt % r}" : r ? "yes" : "no") << "\n"
      "#{f}#{m}-------------------- #{a}\n"
    end
    message(a)
    Logging::message "--------------------\n\n"
    r
  end

  def checking_message(target, place = nil, opt = nil)
    [["in", place], ["with", opt]].inject("#{target}") do |msg, (pre, noun)|
      if noun
        [[:to_str], [:join, ","], [:to_s]].each do |meth, *args|
          if noun.respond_to?(meth)
            #nodyna <send-2224> <SD MODERATE (array)>
            break noun = noun.send(meth, *args)
          end
        end
        msg << " #{pre} #{noun}" unless noun.empty?
      end
      msg
    end
  end


  def have_macro(macro, headers = nil, opt = "", &b)
    checking_for checking_message(macro, headers, opt) do
      macro_defined?(macro, cpp_include(headers), opt, &b)
    end
  end

  def have_library(lib, func = nil, headers = nil, opt = "", &b)
    func = "main" if !func or func.empty?
    lib = with_config(lib+'lib', lib)
    checking_for checking_message(func.funcall_style, LIBARG%lib, opt) do
      if COMMON_LIBS.include?(lib)
        true
      else
        libs = append_library($libs, lib)
        if try_func(func, libs, headers, opt, &b)
          $libs = libs
          true
        else
          false
        end
      end
    end
  end

  def find_library(lib, func, *paths, &b)
    func = "main" if !func or func.empty?
    lib = with_config(lib+'lib', lib)
    paths = paths.collect {|path| path.split(File::PATH_SEPARATOR)}.flatten
    checking_for checking_message(func.funcall_style, LIBARG%lib) do
      libpath = $LIBPATH
      libs = append_library($libs, lib)
      begin
        until r = try_func(func, libs, &b) or paths.empty?
          $LIBPATH = libpath | [paths.shift]
        end
        if r
          $libs = libs
          libpath = nil
        end
      ensure
        $LIBPATH = libpath if libpath
      end
      r
    end
  end

  def have_func(func, headers = nil, opt = "", &b)
    checking_for checking_message(func.funcall_style, headers, opt) do
      if try_func(func, $libs, headers, opt, &b)
        $defs << "-DHAVE_#{func.sans_arguments.tr_cpp}"
        true
      else
        false
      end
    end
  end

  def have_var(var, headers = nil, opt = "", &b)
    checking_for checking_message(var, headers, opt) do
      if try_var(var, headers, opt, &b)
        $defs.push(format("-DHAVE_%s", var.tr_cpp))
        true
      else
        false
      end
    end
  end

  def have_header(header, preheaders = nil, opt = "", &b)
    checking_for header do
      if try_header(cpp_include(preheaders)+cpp_include(header), opt, &b)
        $defs.push(format("-DHAVE_%s", header.tr_cpp))
        true
      else
        false
      end
    end
  end

  def have_framework(fw, &b)
    if Array === fw
      fw, header = *fw
    else
      header = "#{fw}.h"
    end
    checking_for fw do
      src = cpp_include("#{fw}/#{header}") << "\n" "int main(void){return 0;}"
      opt = " -framework #{fw}"
      if try_link(src, opt, &b) or (objc = try_link(src, "-ObjC#{opt}", &b))
        $defs.push(format("-DHAVE_FRAMEWORK_%s", fw.tr_cpp))
        $LDFLAGS << " -ObjC" if objc and /(\A|\s)-ObjC(\s|\z)/ !~ $LDFLAGS
        $LIBS << opt
        true
      else
        false
      end
    end
  end

  def find_header(header, *paths)
    message = checking_message(header, paths)
    header = cpp_include(header)
    checking_for message do
      if try_header(header)
        true
      else
        found = false
        paths.each do |dir|
          opt = "-I#{dir}".quote
          if try_header(header, opt)
            $INCFLAGS << " " << opt
            found = true
            break
          end
        end
        found
      end
    end
  end

  def have_struct_member(type, member, headers = nil, opt = "", &b)
    checking_for checking_message("#{type}.#{member}", headers) do
      if try_compile(<<"SRC", opt, &b)
/*top*/
int s = (char *)&((#{type}*)0)->#{member} - (char *)0;
SRC
        $defs.push(format("-DHAVE_%s_%s", type.tr_cpp, member.tr_cpp))
        $defs.push(format("-DHAVE_ST_%s", member.tr_cpp)) # backward compatibility
        true
      else
        false
      end
    end
  end

  def try_type(type, headers = nil, opt = "", &b)
    if try_compile(<<"SRC", opt, &b)
/*top*/
typedef #{type} conftest_type;
int conftestval[sizeof(conftest_type)?1:-1];
SRC
      $defs.push(format("-DHAVE_TYPE_%s", type.tr_cpp))
      true
    else
      false
    end
  end

  def have_type(type, headers = nil, opt = "", &b)
    checking_for checking_message(type, headers, opt) do
      try_type(type, headers, opt, &b)
    end
  end

  def find_type(type, opt, *headers, &b)
    opt ||= ""
    fmt = "not found"
    def fmt.%(x)
      x ? x.respond_to?(:join) ? x.join(",") : x : self
    end
    checking_for checking_message(type, nil, opt), fmt do
      headers.find do |h|
        try_type(type, h, opt, &b)
      end
    end
  end

  def try_const(const, headers = nil, opt = "", &b)
    const, type = *const
    if try_compile(<<"SRC", opt, &b)
/*top*/
typedef #{type || 'int'} conftest_type;
conftest_type conftestval = #{type ? '' : '(int)'}#{const};
SRC
      $defs.push(format("-DHAVE_CONST_%s", const.tr_cpp))
      true
    else
      false
    end
  end

  def have_const(const, headers = nil, opt = "", &b)
    checking_for checking_message([*const].compact.join(' '), headers, opt) do
      try_const(const, headers, opt, &b)
    end
  end

  STRING_OR_FAILED_FORMAT = "%s"
  def STRING_OR_FAILED_FORMAT.%(x) # :nodoc:
    x ? super : "failed"
  end

  def typedef_expr(type, headers)
    typename, member = type.split('.', 2)
    prelude = cpp_include(headers).split(/$/)
    prelude << "typedef #{typename} rbcv_typedef_;\n"
    return "rbcv_typedef_", member, prelude
  end

  def try_signedness(type, member, headers = nil, opts = nil)
    raise ArgumentError, "don't know how to tell signedness of members" if member
    if try_static_assert("(#{type})-1 < 0", headers, opts)
      return -1
    elsif try_static_assert("(#{type})-1 > 0", headers, opts)
      return +1
    end
  end


  def check_sizeof(type, headers = nil, opts = "", &b)
    typedef, member, prelude = typedef_expr(type, headers)
    prelude << "static #{typedef} *rbcv_ptr_;\n"
    prelude = [prelude]
    expr = "sizeof((*rbcv_ptr_)#{"." << member if member})"
    fmt = STRING_OR_FAILED_FORMAT
    checking_for checking_message("size of #{type}", headers), fmt do
      if size = try_constant(expr, prelude, opts, &b)
        $defs.push(format("-DSIZEOF_%s=%s", type.tr_cpp, size))
        size
      end
    end
  end

  def check_signedness(type, headers = nil, opts = nil, &b)
    typedef, member, prelude = typedef_expr(type, headers)
    signed = nil
    checking_for("signedness of #{type}", STRING_OR_FAILED_FORMAT) do
      signed = try_signedness(typedef, member, [prelude], opts, &b) or next nil
      $defs.push("-DSIGNEDNESS_OF_%s=%+d" % [type.tr_cpp, signed])
      signed < 0 ? "signed" : "unsigned"
    end
    signed
  end

  def convertible_int(type, headers = nil, opts = nil, &b)
    type, macname = *type
    checking_for("convertible type of #{type}", STRING_OR_FAILED_FORMAT) do
      if UNIVERSAL_INTS.include?(type)
        type
      else
        typedef, member, prelude = typedef_expr(type, headers, &b)
        if member
          prelude << "static rbcv_typedef_ rbcv_var;"
          compat = UNIVERSAL_INTS.find {|t|
            try_static_assert("sizeof(rbcv_var.#{member}) == sizeof(#{t})", [prelude], opts, &b)
          }
        else
          next unless signed = try_signedness(typedef, member, [prelude])
          u = "unsigned " if signed > 0
          prelude << "extern rbcv_typedef_ foo();"
          compat = UNIVERSAL_INTS.find {|t|
            try_compile([prelude, "extern #{u}#{t} foo();"].join("\n"), opts, :werror=>true, &b)
          }
        end
        if compat
          macname ||= type.sub(/_(?=t\z)/, '').tr_cpp
          conv = (compat == "long long" ? "LL" : compat.upcase)
          compat = "#{u}#{compat}"
          typename = type.tr_cpp
          $defs.push(format("-DSIZEOF_%s=SIZEOF_%s", typename, compat.tr_cpp))
          $defs.push(format("-DTYPEOF_%s=%s", typename, compat.quote))
          $defs.push(format("-DPRI_%s_PREFIX=PRI_%s_PREFIX", macname, conv))
          conv = (u ? "U" : "") + conv
          $defs.push(format("-D%s2NUM=%s2NUM", macname, conv))
          $defs.push(format("-DNUM2%s=NUM2%s", macname, conv))
          compat
        end
      end
    end
  end

  def scalar_ptr_type?(type, member = nil, headers = nil, &b)
    try_compile(<<"SRC", &b)   # pointer
/*top*/
volatile #{type} conftestval;
extern int t(void);
int t(void) {return (int)(1-*(conftestval#{member ? ".#{member}" : ""}));}
SRC
  end

  def scalar_type?(type, member = nil, headers = nil, &b)
    try_compile(<<"SRC", &b)   # pointer
/*top*/
volatile #{type} conftestval;
extern int t(void);
int t(void) {return (int)(1-(conftestval#{member ? ".#{member}" : ""}));}
SRC
  end

  def have_typeof?
    return $typeof if defined?($typeof)
    $typeof = %w[__typeof__ typeof].find do |t|
      try_compile(<<SRC)
int rbcv_foo;
SRC
    end
  end

  def what_type?(type, member = nil, headers = nil, &b)
    m = "#{type}"
    var = val = "*rbcv_var_"
    func = "rbcv_func_(void)"
    if member
      m << "." << member
    else
      type, member = type.split('.', 2)
    end
    if member
      val = "(#{var}).#{member}"
    end
    prelude = [cpp_include(headers).split(/^/)]
    prelude << ["typedef #{type} rbcv_typedef_;\n",
                "extern rbcv_typedef_ *#{func};\n",
                "static rbcv_typedef_ #{var};\n",
               ]
    type = "rbcv_typedef_"
    fmt = member && !(typeof = have_typeof?) ? "seems %s" : "%s"
    if typeof
      var = "*rbcv_member_"
      func = "rbcv_mem_func_(void)"
      member = nil
      type = "rbcv_mem_typedef_"
      prelude[-1] << "typedef #{typeof}(#{val}) #{type};\n"
      prelude[-1] << "extern #{type} *#{func};\n"
      prelude[-1] << "static #{type} #{var};\n"
      val = var
    end
    def fmt.%(x)
      x ? super : "unknown"
    end
    checking_for checking_message(m, headers), fmt do
      if scalar_ptr_type?(type, member, prelude, &b)
        if try_static_assert("sizeof(*#{var}) == 1", prelude)
          return "string"
        end
        ptr = "*"
      elsif scalar_type?(type, member, prelude, &b)
        unless member and !typeof or try_static_assert("(#{type})-1 < 0", prelude)
          unsigned = "unsigned"
        end
        ptr = ""
      else
        next
      end
      type = UNIVERSAL_INTS.find do |t|
        pre = prelude
        unless member
          pre += [["static #{unsigned} #{t} #{ptr}#{var};\n",
                   "extern #{unsigned} #{t} #{ptr}*#{func};\n"]]
        end
        try_static_assert("sizeof(#{ptr}#{val}) == sizeof(#{unsigned} #{t})", pre)
      end
      type or next
      [unsigned, type, ptr].join(" ").strip
    end
  end

  def find_executable0(bin, path = nil)
    executable_file = proc do |name|
      begin
        stat = File.stat(name)
      rescue SystemCallError
      else
        next name if stat.file? and stat.executable?
      end
    end

    exts = config_string('EXECUTABLE_EXTS') {|s| s.split} || config_string('EXEEXT') {|s| [s]}
    if File.expand_path(bin) == bin
      return bin if executable_file.call(bin)
      if exts
        exts.each {|ext| executable_file.call(file = bin + ext) and return file}
      end
      return nil
    end
    if path ||= ENV['PATH']
      path = path.split(File::PATH_SEPARATOR)
    else
      path = %w[/usr/local/bin /usr/ucb /usr/bin /bin]
    end
    file = nil
    path.each do |dir|
      return file if executable_file.call(file = File.join(dir, bin))
      if exts
        exts.each {|ext| executable_file.call(ext = file + ext) and return ext}
      end
    end
    nil
  end


  def find_executable(bin, path = nil)
    checking_for checking_message(bin, path) do
      find_executable0(bin, path)
    end
  end


  def arg_config(config, default=nil, &block)
    $arg_config << [config, default]
    defaults = []
    if default
      defaults << default
    elsif !block
      defaults << nil
    end
    $configure_args.fetch(config.tr('_', '-'), *defaults, &block)
  end


  def with_config(config, default=nil)
    config = config.sub(/^--with[-_]/, '')
    val = arg_config("--with-"+config) do
      if arg_config("--without-"+config)
        false
      elsif block_given?
        yield(config, default)
      else
        break default
      end
    end
    case val
    when "yes"
      true
    when "no"
      false
    else
      val
    end
  end

  def enable_config(config, default=nil)
    if arg_config("--enable-"+config)
      true
    elsif arg_config("--disable-"+config)
      false
    elsif block_given?
      yield(config, default)
    else
      return default
    end
  end

  def create_header(header = "extconf.h")
    message "creating %s\n", header
    sym = header.tr_cpp
    hdr = ["#ifndef #{sym}\n#define #{sym}\n"]
    for line in $defs
      case line
      when /^-D([^=]+)(?:=(.*))?/
        hdr << "#define #$1 #{$2 ? Shellwords.shellwords($2)[0].gsub(/(?=\t+)/, "\\\n") : 1}\n"
      when /^-U(.*)/
        hdr << "#undef #$1\n"
      end
    end
    hdr << "#endif\n"
    hdr = hdr.join("")
    log_src(hdr, "#{header} is")
    unless (IO.read(header) == hdr rescue false)
      open(header, "wb") do |hfile|
        hfile.write(hdr)
      end
    end
    $extconf_h = header
  end

  def dir_config(target, idefault=nil, ldefault=nil)
    if dir = with_config(target + "-dir", (idefault unless ldefault))
      defaults = Array === dir ? dir : dir.split(File::PATH_SEPARATOR)
      idefault = ldefault = nil
    end

    idir = with_config(target + "-include", idefault)
    $arg_config.last[1] ||= "${#{target}-dir}/include"
    ldir = with_config(target + "-lib", ldefault)
    $arg_config.last[1] ||= "${#{target}-dir}/#{_libdir_basename}"

    idirs = idir ? Array === idir ? idir.dup : idir.split(File::PATH_SEPARATOR) : []
    if defaults
      idirs.concat(defaults.collect {|d| d + "/include"})
      idir = ([idir] + idirs).compact.join(File::PATH_SEPARATOR)
    end
    unless idirs.empty?
      idirs.collect! {|d| "-I" + d}
      idirs -= Shellwords.shellwords($CPPFLAGS)
      unless idirs.empty?
        $CPPFLAGS = (idirs.quote << $CPPFLAGS).join(" ")
      end
    end

    ldirs = ldir ? Array === ldir ? ldir.dup : ldir.split(File::PATH_SEPARATOR) : []
    if defaults
      ldirs.concat(defaults.collect {|d| "#{d}/#{_libdir_basename}"})
      ldir = ([ldir] + ldirs).compact.join(File::PATH_SEPARATOR)
    end
    $LIBPATH = ldirs | $LIBPATH

    [idir, ldir]
  end

  def pkg_config(pkg, option=nil)
    if pkgconfig = with_config("#{pkg}-config") and find_executable0(pkgconfig)
    elsif ($PKGCONFIG ||=
           (pkgconfig = with_config("pkg-config", ("pkg-config" unless CROSS_COMPILING))) &&
           find_executable0(pkgconfig) && pkgconfig) and
        system("#{$PKGCONFIG} --exists #{pkg}")
      pkgconfig = $PKGCONFIG
      get = proc {|opt|
        opt = IO.popen("#{$PKGCONFIG} --#{opt} #{pkg}", err:[:child, :out], &:read)
        opt.strip if $?.success?
      }
    elsif find_executable0(pkgconfig = "#{pkg}-config")
    else
      pkgconfig = nil
    end
    if pkgconfig
      get ||= proc {|opt|
        opt = IO.popen("#{pkgconfig} --#{opt}", err:[:child, :out], &:read)
        opt.strip if $?.success?
      }
    end
    orig_ldflags = $LDFLAGS
    if get and option
      get[option]
    elsif get and try_ldflags(ldflags = get['libs'])
      if incflags = get['cflags-only-I']
        $INCFLAGS << " " << incflags
        cflags = get['cflags-only-other']
      else
        cflags = get['cflags']
      end
      libs = get['libs-only-l']
      if cflags
        $CFLAGS += " " << cflags
        $CXXFLAGS += " " << cflags
      end
      if libs
        ldflags = (Shellwords.shellwords(ldflags) - Shellwords.shellwords(libs)).quote.join(" ")
      else
        libs, ldflags = Shellwords.shellwords(ldflags).partition {|s| s =~ /-l([^ ]+)/ }.map {|l|l.quote.join(" ")}
      end
      $libs += " " << libs

      $LDFLAGS = [orig_ldflags, ldflags].join(' ')
      Logging::message "package configuration for %s\n", pkg
      Logging::message "cflags: %s\nldflags: %s\nlibs: %s\n\n",
                       cflags, ldflags, libs
      [cflags, ldflags, libs]
    else
      Logging::message "package configuration for %s is not found\n", pkg
      nil
    end
  end


  def with_destdir(dir)
    dir = dir.sub($dest_prefix_pattern, '')
    /\A\$[\(\{]/ =~ dir ? dir : "$(DESTDIR)"+dir
  end

  def winsep(s)
    s.tr('/', '\\')
  end

  if !CROSS_COMPILING
    case CONFIG['build_os']
    when 'mingw32'
      def mkintpath(path)
        path = path.dup
        path.tr!('\\', '/')
        path.sub!(/\A([A-Za-z]):(?=\/)/, '/\1')
        path
      end
    when 'cygwin'
      if CONFIG['target_os'] != 'cygwin'
        def mkintpath(path)
          IO.popen(["cygpath", "-u", path], &:read).chomp
        end
      end
    end
  end
  unless method_defined?(:mkintpath)
    def mkintpath(path)
      path
    end
  end

  def configuration(srcdir)
    mk = []
    vpath = $VPATH.dup
    CONFIG["hdrdir"] ||= $hdrdir
    mk << %{
SHELL = /bin/sh

V = 0
Q1 = $(V:1=)
Q = $(Q1:0=@)
ECHO1 = $(V:1=@#{CONFIG['NULLCMD']})
ECHO = $(ECHO1:0=@echo)
NULLCMD = #{CONFIG['NULLCMD']}

srcdir = #{srcdir.gsub(/\$\((srcdir)\)|\$\{(srcdir)\}/) {mkintpath(CONFIG[$1||$2]).unspace}}
topdir = #{mkintpath(topdir = $extmk ? CONFIG["topdir"] : $topdir).unspace}
hdrdir = #{(hdrdir = CONFIG["hdrdir"]) == topdir ? "$(topdir)" : mkintpath(hdrdir).unspace}
arch_hdrdir = #{$arch_hdrdir.quote}
PATH_SEPARATOR = #{CONFIG['PATH_SEPARATOR']}
VPATH = #{vpath.join(CONFIG['PATH_SEPARATOR'])}
}
    if $extmk
      mk << "RUBYLIB =\n""RUBYOPT = -\n"
    end
    prefix = mkintpath(CONFIG["prefix"])
    if destdir = prefix[$dest_prefix_pattern, 1]
      mk << "\nDESTDIR = #{destdir}\n"
      prefix = prefix[destdir.size..-1]
    end
    mk << "prefix = #{with_destdir(prefix).unspace}\n"
    CONFIG.each do |key, var|
      mk << "#{key} = #{with_destdir(mkintpath(var)).unspace}\n" if /.prefix$/ =~ key
    end
    CONFIG.each do |key, var|
      next if /^abs_/ =~ key
      next if /^(?:src|top|hdr)dir$/ =~ key
      next unless /dir$/ =~ key
      mk << "#{key} = #{with_destdir(var)}\n"
    end
    if !$extmk and !$configure_args.has_key?('--ruby') and
        sep = config_string('BUILD_FILE_SEPARATOR')
      sep = ":/=#{sep}"
    else
      sep = ""
    end
    possible_command = (proc {|s| s if /top_srcdir/ !~ s} unless $extmk)
    extconf_h = $extconf_h ? "-DRUBY_EXTCONF_H=\\\"$(RUBY_EXTCONF_H)\\\" " : $defs.join(" ") << " "
    headers = %w[
      $(hdrdir)/ruby.h
      $(hdrdir)/ruby/ruby.h
      $(hdrdir)/ruby/defines.h
      $(hdrdir)/ruby/missing.h
      $(hdrdir)/ruby/intern.h
      $(hdrdir)/ruby/st.h
      $(hdrdir)/ruby/subst.h
    ]
    if RULE_SUBST
      headers.each {|h| h.sub!(/.*/, &RULE_SUBST.method(:%))}
    end
    headers << $config_h
    headers << '$(RUBY_EXTCONF_H)' if $extconf_h
    mk << %{

CC = #{CONFIG['CC']}
CXX = #{CONFIG['CXX']}
LIBRUBY = #{CONFIG['LIBRUBY']}
LIBRUBY_A = #{CONFIG['LIBRUBY_A']}
LIBRUBYARG_SHARED = #$LIBRUBYARG_SHARED
LIBRUBYARG_STATIC = #$LIBRUBYARG_STATIC
empty =
OUTFLAG = #{OUTFLAG}$(empty)
COUTFLAG = #{COUTFLAG}$(empty)

RUBY_EXTCONF_H = #{$extconf_h}
cflags   = #{CONFIG['cflags']}
optflags = #{CONFIG['optflags']}
debugflags = #{CONFIG['debugflags']}
warnflags = #{$warnflags}
CCDLFLAGS = #{$static ? '' : CONFIG['CCDLFLAGS']}
CFLAGS   = $(CCDLFLAGS) #$CFLAGS $(ARCH_FLAG)
INCFLAGS = -I. #$INCFLAGS
DEFS     = #{CONFIG['DEFS']}
CPPFLAGS = #{extconf_h}#{$CPPFLAGS}
CXXFLAGS = $(CCDLFLAGS) #$CXXFLAGS $(ARCH_FLAG)
ldflags  = #{$LDFLAGS}
dldflags = #{$DLDFLAGS} #{CONFIG['EXTDLDFLAGS']}
ARCH_FLAG = #{$ARCH_FLAG}
DLDFLAGS = $(ldflags) $(dldflags) $(ARCH_FLAG)
LDSHARED = #{CONFIG['LDSHARED']}
LDSHAREDXX = #{config_string('LDSHAREDXX') || '$(LDSHARED)'}
AR = #{CONFIG['AR']}
EXEEXT = #{CONFIG['EXEEXT']}

}
    CONFIG.each do |key, val|
      mk << "#{key} = #{val}\n" if /^RUBY.*NAME/ =~ key
    end
    mk << %{
arch = #{CONFIG['arch']}
sitearch = #{CONFIG['sitearch']}
ruby_version = #{RbConfig::CONFIG['ruby_version']}
ruby = #{$ruby.sub(%r[\A#{Regexp.quote(RbConfig::CONFIG['bindir'])}(?=/|\z)]) {'$(bindir)'}}
RUBY = $(ruby#{sep})
ruby_headers = #{headers.join(' ')}

RM = #{config_string('RM', &possible_command) || '$(RUBY) -run -e rm -- -f'}
RM_RF = #{'$(RUBY) -run -e rm -- -rf'}
RMDIRS = #{config_string('RMDIRS', &possible_command) || '$(RUBY) -run -e rmdir -- -p'}
MAKEDIRS = #{config_string('MAKEDIRS', &possible_command) || '@$(RUBY) -run -e mkdir -- -p'}
INSTALL = #{config_string('INSTALL', &possible_command) || '@$(RUBY) -run -e install -- -vp'}
INSTALL_PROG = #{config_string('INSTALL_PROG') || '$(INSTALL) -m 0755'}
INSTALL_DATA = #{config_string('INSTALL_DATA') || '$(INSTALL) -m 0644'}
COPY = #{config_string('CP', &possible_command) || '@$(RUBY) -run -e cp -- -v'}
TOUCH = exit >


preload = #{defined?($preload) && $preload ? $preload.join(' ') : ''}
}
    if $nmake == ?b
      mk.each do |x|
        x.gsub!(/^(MAKEDIRS|INSTALL_(?:PROG|DATA))+\s*=.*\n/) do
          "!ifndef " + $1 + "\n" +
          $& +
          "!endif\n"
        end
      end
    end
    mk
  end

  def timestamp_file(name, target_prefix = nil)
    if target_prefix
      pat = []
      install_dirs.each do |n, d|
        pat << n if /\$\(target_prefix\)\z/ =~ d
      end
      name = name.gsub(/\$\((#{pat.join("|")})\)/) {$&+target_prefix}
    end
    name = name.gsub(/(\$[({]|[})])|(\/+)|[^-.\w]+/) {$1 ? "" : $2 ? ".-." : "_"}
    "$(TIMESTAMP_DIR)/.#{name}.time"
  end

  def dummy_makefile(srcdir)
    configuration(srcdir) << <<RULES << CLEANINGS
CLEANFILES = #{$cleanfiles.join(' ')}
DISTCLEANFILES = #{$distcleanfiles.join(' ')}

all install static install-so install-rb: Makefile
.PHONY: all install static install-so install-rb
.PHONY: clean clean-so clean-static clean-rb

RULES
  end

  def each_compile_rules # :nodoc:
    vpath_splat = /\$\(\*VPATH\*\)/
    COMPILE_RULES.each do |rule|
      if vpath_splat =~ rule
        $VPATH.each do |path|
          yield rule.sub(vpath_splat) {path}
        end
      else
        yield rule
      end
    end
  end

  def depend_rules(depend)
    suffixes = []
    depout = []
    cont = implicit = nil
    impconv = proc do
      each_compile_rules {|rule| depout << (rule % implicit[0]) << implicit[1]}
      implicit = nil
    end
    ruleconv = proc do |line|
      if implicit
        if /\A\t/ =~ line
          implicit[1] << line
          next
        else
          impconv[]
        end
      end
      if m = /\A\.(\w+)\.(\w+)(?:\s*:)/.match(line)
        suffixes << m[1] << m[2]
        implicit = [[m[1], m[2]], [m.post_match]]
        next
      elsif RULE_SUBST and /\A(?!\s*\w+\s*=)[$\w][^#]*:/ =~ line
        line.sub!(/\s*\#.*$/, '')
        comment = $&
        line.gsub!(%r"(\s)(?!\.)([^$(){}+=:\s\\,]+)(?=\s|\z)") {$1 + RULE_SUBST % $2}
        line = line.chomp + comment + "\n" if comment
      end
      depout << line
    end
    depend.each_line do |line|
      line.gsub!(/\.o\b/, ".#{$OBJEXT}")
      line.gsub!(/\{\$\(VPATH\)\}/, "") unless $nmake
      line.gsub!(/\$\((?:hdr|top)dir\)\/config.h/, $config_h)
      line.gsub!(%r"\$\(hdrdir\)/(?!ruby(?![^:;/\s]))(?=[-\w]+\.h)", '\&ruby/')
      if $nmake && /\A\s*\$\(RM|COPY\)/ =~ line
        line.gsub!(%r"[-\w\./]{2,}"){$&.tr("/", "\\")}
        line.gsub!(/(\$\((?!RM|COPY)[^:)]+)(?=\))/, '\1:/=\\')
      end
      if /(?:^|[^\\])(?:\\\\)*\\$/ =~ line
        (cont ||= []) << line
        next
      elsif cont
        line = (cont << line).join
        cont = nil
      end
      ruleconv.call(line)
    end
    if cont
      ruleconv.call(cont.join)
    elsif implicit
      impconv.call
    end
    unless suffixes.empty?
      depout.unshift(".SUFFIXES: ." + suffixes.uniq.join(" .") + "\n\n")
    end
    depout.unshift("$(OBJS): $(RUBY_EXTCONF_H)\n\n") if $extconf_h
    depout.flatten!
    depout
  end

  def create_makefile(target, srcprefix = nil)
    $target = target
    libpath = $LIBPATH|$DEFLIBPATH
    message "creating Makefile\n"
    MakeMakefile.rm_f "#{CONFTEST}*"
    if CONFIG["DLEXT"] == $OBJEXT
      for lib in libs = $libs.split
        lib.sub!(/-l(.*)/, %%"lib\\1.#{$LIBEXT}"%)
      end
      $defs.push(format("-DEXTLIB='%s'", libs.join(",")))
    end

    if target.include?('/')
      target_prefix, target = File.split(target)
      target_prefix[0,0] = '/'
    else
      target_prefix = ""
    end

    srcprefix ||= "$(srcdir)/#{srcprefix}".chomp('/')
    RbConfig.expand(srcdir = srcprefix.dup)

    ext = ".#{$OBJEXT}"
    orig_srcs = Dir[File.join(srcdir, "*.{#{SRC_EXT.join(%q{,})}}")]
    if not $objs
      srcs = $srcs || orig_srcs
      objs = srcs.inject(Hash.new {[]}) {|h, f| h[File.basename(f, ".*") << ext] <<= f; h}
      $objs = objs.keys
      unless objs.delete_if {|b, f| f.size == 1}.empty?
        dups = objs.sort.map {|b, f|
          "#{b[/.*\./]}{#{f.collect {|n| n[/([^.]+)\z/]}.join(',')}}"
        }
        abort "source files duplication - #{dups.join(", ")}"
      end
    else
      $objs.collect! {|o| File.basename(o, ".*") << ext} unless $OBJEXT == "o"
      srcs = $srcs || $objs.collect {|o| o.chomp(ext) << ".c"}
    end
    $srcs = srcs

    hdrs = Dir[File.join(srcdir, "*.{#{HDR_EXT.join(%q{,})}}")]

    target = nil if $objs.empty?

    if target and EXPORT_PREFIX
      if File.exist?(File.join(srcdir, target + '.def'))
        deffile = "$(srcdir)/$(TARGET).def"
        unless EXPORT_PREFIX.empty?
          makedef = %{-pe "$_.sub!(/^(?=\\w)/,'#{EXPORT_PREFIX}') unless 1../^EXPORTS$/i"}
        end
      else
        makedef = %{-e "puts 'EXPORTS', '$(TARGET_ENTRY)'"}
      end
      if makedef
        $cleanfiles << '$(DEFFILE)'
        origdef = deffile
        deffile = "$(TARGET)-$(arch).def"
      end
    end
    origdef ||= ''

    if $extout and $INSTALLFILES
      $cleanfiles.concat($INSTALLFILES.collect {|files, dir|File.join(dir, files.sub(/\A\.\//, ''))})
      $distcleandirs.concat($INSTALLFILES.collect {|files, dir| dir})
    end

    if $extmk and $static
      $defs << "-DRUBY_EXPORT=1"
    end

    if $extmk and not $extconf_h
      create_header
    end

    libpath = libpathflag(libpath)

    dllib = target ? "$(TARGET).#{CONFIG['DLEXT']}" : ""
    staticlib = target ? "$(TARGET).#$LIBEXT" : ""
    mfile = open("Makefile", "wb")
    conf = configuration(srcprefix)
    conf = yield(conf) if block_given?
    mfile.puts(conf)
    mfile.print "
libpath = #{($LIBPATH|$DEFLIBPATH).join(" ")}
LIBPATH = #{libpath}
DEFFILE = #{deffile}

CLEANFILES = #{$cleanfiles.join(' ')}
DISTCLEANFILES = #{$distcleanfiles.join(' ')}
DISTCLEANDIRS = #{$distcleandirs.join(' ')}

extout = #{$extout && $extout.quote}
extout_prefix = #{$extout_prefix}
target_prefix = #{target_prefix}
LOCAL_LIBS = #{$LOCAL_LIBS}
LIBS = #{$LIBRUBYARG} #{$libs} #{$LIBS}
ORIG_SRCS = #{orig_srcs.collect(&File.method(:basename)).join(' ')}
SRCS = $(ORIG_SRCS) #{(srcs - orig_srcs).collect(&File.method(:basename)).join(' ')}
OBJS = #{$objs.join(" ")}
HDRS = #{hdrs.map{|h| '$(srcdir)/' + File.basename(h)}.join(' ')}
TARGET = #{target}
TARGET_NAME = #{target && target[/\A\w+/]}
TARGET_ENTRY = #{EXPORT_PREFIX || ''}Init_$(TARGET_NAME)
DLLIB = #{dllib}
EXTSTATIC = #{$static || ""}
STATIC_LIB = #{staticlib unless $static.nil?}
TIMESTAMP_DIR = #{$extout ? '$(extout)/.timestamp' : '.'}
" #"
    install_dirs.each {|d| mfile.print("%-14s= %s\n" % d) if /^[[:upper:]]/ =~ d[0]}
    n = ($extout ? '$(RUBYARCHDIR)/' : '') + '$(TARGET)'
    mfile.print "
TARGET_SO     = #{($extout ? '$(RUBYARCHDIR)/' : '')}$(DLLIB)
CLEANLIBS     = #{n}.#{CONFIG['DLEXT']} #{config_string('cleanlibs') {|t| t.gsub(/\$\*/) {n}}}
CLEANOBJS     = *.#{$OBJEXT} #{config_string('cleanobjs') {|t| t.gsub(/\$\*/, "$(TARGET)#{deffile ? '-$(arch)': ''}")} if target} *.bak

all:    #{$extout ? "install" : target ? "$(DLLIB)" : "Makefile"}
static: $(STATIC_LIB)#{$extout ? " install-rb" : ""}
.PHONY: all install static install-so install-rb
.PHONY: clean clean-so clean-static clean-rb
"
    mfile.print CLEANINGS
    fsep = config_string('BUILD_FILE_SEPARATOR') {|s| s unless s == "/"}
    if fsep
      sep = ":/=#{fsep}"
      fseprepl = proc {|s|
        s = s.gsub("/", fsep)
        s = s.gsub(/(\$\(\w+)(\))/) {$1+sep+$2}
        s.gsub(/(\$\{\w+)(\})/) {$1+sep+$2}
      }
      rsep = ":#{fsep}=/"
    else
      fseprepl = proc {|s| s}
      sep = ""
      rsep = ""
    end
    dirs = []
    mfile.print "install: install-so install-rb\n\n"
    sodir = (dir = "$(RUBYARCHDIR)").dup
    mfile.print("install-so: ")
    if target
      f = "$(DLLIB)"
      dest = "#{dir}/#{f}"
      if $extout
        mfile.puts dest
        mfile.print "clean-so::\n"
        mfile.print "\t-$(Q)$(RM) #{fseprepl[dest]}\n"
        mfile.print "\t-$(Q)$(RMDIRS) #{fseprepl[dir]}#{$ignore_error}\n"
      else
        mfile.print "#{f} #{timestamp_file(dir, target_prefix)}\n"
        mfile.print "\t$(INSTALL_PROG) #{fseprepl[f]} #{dir}\n"
        if defined?($installed_list)
          mfile.print "\t@echo #{dir}/#{File.basename(f)}>>$(INSTALLED_LIST)\n"
        end
      end
      mfile.print "clean-static::\n"
      mfile.print "\t-$(Q)$(RM) $(STATIC_LIB)\n"
    else
      mfile.puts "Makefile"
    end
    mfile.print("install-rb: pre-install-rb install-rb-default\n")
    mfile.print("install-rb-default: pre-install-rb-default\n")
    mfile.print("pre-install-rb: Makefile\n")
    mfile.print("pre-install-rb-default: Makefile\n")
    for sfx, i in [["-default", [["lib/**/*.rb", "$(RUBYLIBDIR)", "lib"]]], ["", $INSTALLFILES]]
      files = install_files(mfile, i, nil, srcprefix) or next
      for dir, *files in files
        unless dirs.include?(dir)
          dirs << dir
          mfile.print "pre-install-rb#{sfx}: #{timestamp_file(dir, target_prefix)}\n"
        end
        for f in files
          dest = "#{dir}/#{File.basename(f)}"
          mfile.print("install-rb#{sfx}: #{dest}\n")
          mfile.print("#{dest}: #{f} #{timestamp_file(dir, target_prefix)}\n")
          mfile.print("\t$(Q) $(#{$extout ? 'COPY' : 'INSTALL_DATA'}) #{f} $(@D)\n")
          if defined?($installed_list) and !$extout
            mfile.print("\t@echo #{dest}>>$(INSTALLED_LIST)\n")
          end
          if $extout
            mfile.print("clean-rb#{sfx}::\n")
            mfile.print("\t-$(Q)$(RM) #{fseprepl[dest]}\n")
          end
        end
      end
      mfile.print "pre-install-rb#{sfx}:\n"
      if files.empty?
        mfile.print("\t@$(NULLCMD)\n")
      else
        mfile.print("\t$(ECHO) installing#{sfx.sub(/^-/, " ")} #{target} libraries\n")
      end
      if $extout
        dirs.uniq!
        unless dirs.empty?
          mfile.print("clean-rb#{sfx}::\n")
          for dir in dirs.sort_by {|d| -d.count('/')}
            mfile.print("\t-$(Q)$(RMDIRS) #{fseprepl[dir]}#{$ignore_error}\n")
          end
        end
      end
    end
    dirs.unshift(sodir) if target and !dirs.include?(sodir)
    dirs.each do |d|
      t = timestamp_file(d, target_prefix)
      mfile.print "#{t}:\n\t$(Q) $(MAKEDIRS) $(@D) #{d}\n\t$(Q) $(TOUCH) $@\n"
    end

    mfile.print <<-SITEINSTALL

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

    SITEINSTALL

    return unless target

    mfile.puts SRC_EXT.collect {|e| ".path.#{e} = $(VPATH)"} if $nmake == ?b
    mfile.print ".SUFFIXES: .#{(SRC_EXT + [$OBJEXT, $ASMEXT]).compact.join(' .')}\n"
    mfile.print "\n"

    compile_command = "\n\t$(ECHO) compiling $(<#{rsep})\n\t$(Q) %s\n\n"
    command = compile_command % COMPILE_CXX
    asm_command = compile_command.sub(/compiling/, 'translating') % ASSEMBLE_CXX
    CXX_EXT.each do |e|
      each_compile_rules do |rule|
        mfile.printf(rule, e, $OBJEXT)
        mfile.print(command)
        mfile.printf(rule, e, $ASMEXT)
        mfile.print(asm_command)
      end
    end
    command = compile_command % COMPILE_C
    asm_command = compile_command.sub(/compiling/, 'translating') % ASSEMBLE_C
    C_EXT.each do |e|
      each_compile_rules do |rule|
        mfile.printf(rule, e, $OBJEXT)
        mfile.print(command)
        mfile.printf(rule, e, $ASMEXT)
        mfile.print(asm_command)
      end
    end

    mfile.print "$(RUBYARCHDIR)/" if $extout
    mfile.print "$(DLLIB): "
    mfile.print "$(DEFFILE) " if makedef
    mfile.print "$(OBJS) Makefile"
    mfile.print " #{timestamp_file('$(RUBYARCHDIR)', target_prefix)}" if $extout
    mfile.print "\n"
    mfile.print "\t$(ECHO) linking shared-object #{target_prefix.sub(/\A\/(.*)/, '\1/')}$(DLLIB)\n"
    mfile.print "\t-$(Q)$(RM) $(@#{sep})\n"
    link_so = LINK_SO.gsub(/^/, "\t$(Q) ")
    if srcs.any?(&%r"\.(?:#{CXX_EXT.join('|')})\z".method(:===))
      link_so = link_so.sub(/\bLDSHARED\b/, '\&XX')
    end
    mfile.print link_so, "\n\n"
    unless $static.nil?
      mfile.print "$(STATIC_LIB): $(OBJS)\n\t-$(Q)$(RM) $(@#{sep})\n\t"
      mfile.print "$(ECHO) linking static-library $(@#{rsep})\n\t$(Q) "
      mfile.print "$(AR) #{config_string('ARFLAGS') || 'cru '}$@ $(OBJS)"
      config_string('RANLIB') do |ranlib|
        mfile.print "\n\t-$(Q)#{ranlib} $(@) 2> /dev/null || true"
      end
    end
    mfile.print "\n\n"
    if makedef
      mfile.print "$(DEFFILE): #{origdef}\n"
      mfile.print "\t$(ECHO) generating $(@#{rsep})\n"
      mfile.print "\t$(Q) $(RUBY) #{makedef} #{origdef} > $@\n\n"
    end

    depend = File.join(srcdir, "depend")
    if File.exist?(depend)
      mfile.print("###\n", *depend_rules(File.read(depend)))
    else
      mfile.print "$(OBJS): $(HDRS) $(ruby_headers)\n"
    end

    $makefile_created = true
  ensure
    mfile.close if mfile
  end


  def init_mkmf(config = CONFIG, rbconfig = RbConfig::CONFIG)
    $makefile_created = false
    $arg_config = []
    $enable_shared = config['ENABLE_SHARED'] == 'yes'
    $defs = []
    $extconf_h = nil
    if $warnflags = CONFIG['warnflags'] and CONFIG['GCC'] == 'yes'
      config['warnflags'] = $warnflags.gsub(/(\A|\s)-Werror[-=]/, '\1-W')
      RbConfig.expand(rbconfig['warnflags'] = config['warnflags'].dup)
      config.each do |key, val|
        RbConfig.expand(rbconfig[key] = val.dup) if /warnflags/ =~ val
      end
      $warnflags = config['warnflags'] unless $extmk
    end
    $CFLAGS = with_config("cflags", arg_config("CFLAGS", config["CFLAGS"])).dup
    $CXXFLAGS = (with_config("cxxflags", arg_config("CXXFLAGS", config["CXXFLAGS"]))||'').dup
    $ARCH_FLAG = with_config("arch_flag", arg_config("ARCH_FLAG", config["ARCH_FLAG"])).dup
    $CPPFLAGS = with_config("cppflags", arg_config("CPPFLAGS", config["CPPFLAGS"])).dup
    $LDFLAGS = with_config("ldflags", arg_config("LDFLAGS", config["LDFLAGS"])).dup
    $INCFLAGS = "-I$(arch_hdrdir)"
    $INCFLAGS << " -I$(hdrdir)/ruby/backward" unless $extmk
    $INCFLAGS << " -I$(hdrdir) -I$(srcdir)"
    $DLDFLAGS = with_config("dldflags", arg_config("DLDFLAGS", config["DLDFLAGS"])).dup
    $LIBEXT = config['LIBEXT'].dup
    $OBJEXT = config["OBJEXT"].dup
    $EXEEXT = config["EXEEXT"].dup
    $ASMEXT = config_string('ASMEXT', &:dup) || 'S'
    $LIBS = "#{config['LIBS']} #{config['DLDLIBS']}"
    $LIBRUBYARG = ""
    $LIBRUBYARG_STATIC = config['LIBRUBYARG_STATIC']
    $LIBRUBYARG_SHARED = config['LIBRUBYARG_SHARED']
    $DEFLIBPATH = [$extmk ? "$(topdir)" : "$(#{config["libdirname"] || "libdir"})"]
    $DEFLIBPATH.unshift(".")
    $LIBPATH = []
    $INSTALLFILES = []
    $NONINSTALLFILES = [/~\z/, /\A#.*#\z/, /\A\.#/, /\.bak\z/i, /\.orig\z/, /\.rej\z/, /\.l[ao]\z/, /\.o\z/]
    $VPATH = %w[$(srcdir) $(arch_hdrdir)/ruby $(hdrdir)/ruby]

    $objs = nil
    $srcs = nil
    $libs = ""
    if $enable_shared or RbConfig.expand(config["LIBRUBY"].dup) != RbConfig.expand(config["LIBRUBY_A"].dup)
      $LIBRUBYARG = config['LIBRUBYARG']
    end

    $LOCAL_LIBS = ""

    $cleanfiles = config_string('CLEANFILES') {|s| Shellwords.shellwords(s)} || []
    $cleanfiles << "mkmf.log"
    $distcleanfiles = config_string('DISTCLEANFILES') {|s| Shellwords.shellwords(s)} || []
    $distcleandirs = config_string('DISTCLEANDIRS') {|s| Shellwords.shellwords(s)} || []

    $extout ||= nil
    $extout_prefix ||= nil

    $arg_config.clear
    dir_config("opt")
  end

  FailedMessage = <<MESSAGE
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.

Provided configuration options:
MESSAGE

  def mkmf_failed(path)
    unless $makefile_created or File.exist?("Makefile")
      opts = $arg_config.collect {|t, n| "\t#{t}#{n ? "=#{n}" : ""}\n"}
      abort "*** #{path} failed ***\n" + FailedMessage + opts.join
    end
  end

  private

  def _libdir_basename
    @libdir_basename ||= config_string("libdir") {|name| name[/\A\$\(exec_prefix\)\/(.*)/, 1]} || "lib"
  end

  def MAIN_DOES_NOTHING(*refs)
    src = MAIN_DOES_NOTHING
    unless refs.empty?
      src = src.sub(/\{/) do
        $& +
          "\n  if (argc > 1000000) {\n" +
          refs.map {|n|"    printf(\"%p\", &#{n});\n"}.join("") +
          "  }\n"
      end
    end
    src
  end

  extend self
  init_mkmf

  $make = with_config("make-prog", ENV["MAKE"] || "make")
  make, = Shellwords.shellwords($make)
  $nmake = nil
  case
  when $mswin
    $nmake = ?m if /nmake/i =~ make
  when $bccwin
    $nmake = ?b if /Borland/i =~ `#{make} -h`
  end
  $ignore_error = $nmake ? '' : ' 2> /dev/null || true'

  RbConfig::CONFIG["srcdir"] = CONFIG["srcdir"] =
    $srcdir = arg_config("--srcdir", File.dirname($0))
  $configure_args["--topsrcdir"] ||= $srcdir
  if $curdir = arg_config("--curdir")
    RbConfig.expand(curdir = $curdir.dup)
  else
    curdir = $curdir = "."
  end
  unless File.expand_path(RbConfig::CONFIG["topdir"]) == File.expand_path(curdir)
    CONFIG["topdir"] = $curdir
    RbConfig::CONFIG["topdir"] = curdir
  end
  $configure_args["--topdir"] ||= $curdir
  $ruby = arg_config("--ruby", File.join(RbConfig::CONFIG["bindir"], CONFIG["ruby_install_name"]))

  RbConfig.expand(CONFIG["RUBY_SO_NAME"])


  split = Shellwords.method(:shellwords).to_proc

  EXPORT_PREFIX = config_string('EXPORT_PREFIX') {|s| s.strip}

  hdr = ['#include "ruby.h"' "\n"]
  config_string('COMMON_MACROS') do |s|
    Shellwords.shellwords(s).each do |w|
      w, v = w.split(/=/, 2)
      hdr << "#ifndef #{w}"
      hdr << "#define #{[w, v].compact.join(" ")}"
      hdr << "#endif /* #{w} */"
    end
  end
  config_string('COMMON_HEADERS') do |s|
    Shellwords.shellwords(s).each {|w| hdr << "#include <#{w}>"}
  end


  COMMON_HEADERS = hdr.join("\n")


  COMMON_LIBS = config_string('COMMON_LIBS', &split) || []


  COMPILE_RULES = config_string('COMPILE_RULES', &split) || %w[.%s.%s:]
  RULE_SUBST = config_string('RULE_SUBST')


  COMPILE_C = config_string('COMPILE_C') || '$(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $<'


  COMPILE_CXX = config_string('COMPILE_CXX') || '$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $<'


  ASSEMBLE_C = config_string('ASSEMBLE_C') || COMPILE_C.sub(/(?<=\s)-c(?=\s)/, '-S')


  ASSEMBLE_CXX = config_string('ASSEMBLE_CXX') || COMPILE_CXX.sub(/(?<=\s)-c(?=\s)/, '-S')


  TRY_LINK = config_string('TRY_LINK') ||
    "$(CC) #{OUTFLAG}#{CONFTEST}#{$EXEEXT} $(INCFLAGS) $(CPPFLAGS) " \
    "$(CFLAGS) $(src) $(LIBPATH) $(LDFLAGS) $(ARCH_FLAG) $(LOCAL_LIBS) $(LIBS)"


  LINK_SO = (config_string('LINK_SO') || "").sub(/^$/) do
    if CONFIG["DLEXT"] == $OBJEXT
      "ld $(DLDFLAGS) -r -o $@ $(OBJS)\n"
    else
      "$(LDSHARED) #{OUTFLAG}$@ $(OBJS) " \
      "$(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS)"
    end
  end


  LIBPATHFLAG = config_string('LIBPATHFLAG') || ' -L%s'
  RPATHFLAG = config_string('RPATHFLAG') || ''


  LIBARG = config_string('LIBARG') || '-l%s'


  MAIN_DOES_NOTHING = config_string('MAIN_DOES_NOTHING') || "int main(int argc, char **argv)\n{\n  return 0;\n}"
  UNIVERSAL_INTS = config_string('UNIVERSAL_INTS') {|s| Shellwords.shellwords(s)} ||
    %w[int short long long\ long]

  sep = config_string('BUILD_FILE_SEPARATOR') {|s| ":/=#{s}" if s != "/"} || ""


  CLEANINGS = "
clean-static::
clean-rb-default::
clean-rb::
clean-so::
clean: clean-so clean-static clean-rb-default clean-rb
\t\t-$(Q)$(RM) $(CLEANLIBS#{sep}) $(CLEANOBJS#{sep}) $(CLEANFILES#{sep}) .*.time

distclean-rb-default::
distclean-rb::
distclean-so::
distclean-static::
distclean: clean distclean-so distclean-static distclean-rb-default distclean-rb
\t\t-$(Q)$(RM) Makefile $(RUBY_EXTCONF_H) #{CONFTEST}.* mkmf.log
\t\t-$(Q)$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES#{sep})
\t\t-$(Q)$(RMDIRS) $(DISTCLEANDIRS#{sep})#{$ignore_error}

realclean: distclean
"
end

include MakeMakefile

if not $extmk and /\A(extconf|makefile).rb\z/ =~ File.basename($0)
  END {mkmf_failed($0)}
end
