
require "fileutils"
require "optparse"

module FileUtils
  @fileutils_output = $stdout
end

def setup(options = "", *long_options)
  caller = caller_locations(1, 1)[0].label
  opt_hash = {}
  argv = []
  OptionParser.new do |o|
    options.scan(/.:?/) do |s|
      opt_name = s.delete(":").intern
      o.on("-" + s.tr(":", " ")) do |val|
        opt_hash[opt_name] = val
      end
    end
    long_options.each do |s|
      opt_name, arg_name = s.split(/(?=[\s=])/, 2)
      opt_name.sub!(/\A--/, '')
      s = "--#{opt_name.gsub(/([A-Z]+|[a-z])([A-Z])/, '\1-\2').downcase}#{arg_name}"
      puts "#{opt_name}=>#{s}" if $DEBUG
      opt_name = opt_name.intern
      o.on(s) do |val|
        opt_hash[opt_name] = val
      end
    end
    o.on("-v") do opt_hash[:verbose] = true end
    o.on("--help") do
      UN.help([caller])
      exit
    end
    o.order!(ARGV) do |x|
      if /[*?\[{]/ =~ x
        argv.concat(Dir[x])
      else
        argv << x
      end
    end
  end
  yield argv, opt_hash
end


def cp
  setup("pr") do |argv, options|
    cmd = "cp"
    cmd += "_r" if options.delete :r
    options[:preserve] = true if options.delete :p
    dest = argv.pop
    argv = argv[0] if argv.size == 1
    #nodyna <send-1911> <SD TRIVIAL (public methods)>
    FileUtils.send cmd, argv, dest, options
  end
end


def ln
  setup("sf") do |argv, options|
    cmd = "ln"
    cmd += "_s" if options.delete :s
    options[:force] = true if options.delete :f
    dest = argv.pop
    argv = argv[0] if argv.size == 1
    #nodyna <send-1912> <SD TRIVIAL (public methods)>
    FileUtils.send cmd, argv, dest, options
  end
end


def mv
  setup do |argv, options|
    dest = argv.pop
    argv = argv[0] if argv.size == 1
    FileUtils.mv argv, dest, options
  end
end


def rm
  setup("fr") do |argv, options|
    cmd = "rm"
    cmd += "_r" if options.delete :r
    options[:force] = true if options.delete :f
    #nodyna <send-1913> <SD TRIVIAL (public methods)>
    FileUtils.send cmd, argv, options
  end
end


def mkdir
  setup("p") do |argv, options|
    cmd = "mkdir"
    cmd += "_p" if options.delete :p
    #nodyna <send-1914> <SD TRIVIAL (public methods)>
    FileUtils.send cmd, argv, options
  end
end


def rmdir
  setup("p") do |argv, options|
    options[:parents] = true if options.delete :p
    FileUtils.rmdir argv, options
  end
end


def install
  setup("pm:") do |argv, options|
    options[:mode] = (mode = options.delete :m) ? mode.oct : 0755
    options[:preserve] = true if options.delete :p
    dest = argv.pop
    argv = argv[0] if argv.size == 1
    FileUtils.install argv, dest, options
  end
end


def chmod
  setup do |argv, options|
    mode = argv.shift.oct
    FileUtils.chmod mode, argv, options
  end
end


def touch
  setup do |argv, options|
    FileUtils.touch argv, options
  end
end


def wait_writable
  setup("n:w:v") do |argv, options|
    verbose = options[:verbose]
    n = options[:n] and n = Integer(n)
    wait = (wait = options[:w]) ? Float(wait) : 0.2
    argv.each do |file|
      begin
        open(file, "r+b")
      rescue Errno::ENOENT
        break
      rescue Errno::EACCES => e
        raise if n and (n -= 1) <= 0
        if verbose
          puts e
          STDOUT.flush
        end
        sleep wait
        retry
      end
    end
  end
end


def mkmf
  setup("d:h:l:f:v:t:m:c:", "vendor") do |argv, options|
    require 'mkmf'
    opt = options[:d] and opt.split(/:/).each {|n| dir_config(*n.split(/,/))}
    opt = options[:h] and opt.split(/:/).each {|n| have_header(*n.split(/,/))}
    opt = options[:l] and opt.split(/:/).each {|n| have_library(*n.split(/,/))}
    opt = options[:f] and opt.split(/:/).each {|n| have_func(*n.split(/,/))}
    opt = options[:v] and opt.split(/:/).each {|n| have_var(*n.split(/,/))}
    opt = options[:t] and opt.split(/:/).each {|n| have_type(*n.split(/,/))}
    opt = options[:m] and opt.split(/:/).each {|n| have_macro(*n.split(/,/))}
    opt = options[:c] and opt.split(/:/).each {|n| have_const(*n.split(/,/))}
    $configure_args["--vendor"] = true if options[:vendor]
    create_makefile(*argv)
  end
end


def httpd
  setup("", "BindAddress=ADDR", "Port=PORT", "MaxClients=NUM", "TempDir=DIR",
        "DoNotReverseLookup", "RequestTimeout=SECOND", "HTTPVersion=VERSION") do
    |argv, options|
    require 'webrick'
    opt = options[:RequestTimeout] and options[:RequestTimeout] = opt.to_i
    [:Port, :MaxClients].each do |name|
      opt = options[name] and (options[name] = Integer(opt)) rescue nil
    end
    unless argv.size == 1
      raise ArgumentError, "DocumentRoot is mandatory"
    end
    options[:DocumentRoot] = argv.shift
    s = WEBrick::HTTPServer.new(options)
    shut = proc {s.shutdown}
    siglist = %w"TERM QUIT"
    siglist.concat(%w"HUP INT") if STDIN.tty?
    siglist &= Signal.list.keys
    siglist.each do |sig|
      Signal.trap(sig, shut)
    end
    s.start
  end
end


def help
  setup do |argv,|
    UN.help(argv)
  end
end

module UN # :nodoc:
  module_function
  def help(argv, output: $stdout)
    all = argv.empty?
    cmd = nil
    if all
      store = proc {|msg| output << msg}
    else
      messages = {}
      store = proc {|msg| messages[cmd] = msg}
    end
    open(__FILE__) do |me|
      while me.gets("##\n")
        if help = me.gets("\n\n")
          if all or argv.include?(cmd = help[/^#\s*ruby\s.*-e\s+(\w+)/, 1])
            store[help.gsub(/^# ?/, "")]
            break unless all or argv.size > messages.size
          end
        end
      end
    end
    if messages
      argv.each {|cmd| output << messages[cmd]}
    end
  end
end
