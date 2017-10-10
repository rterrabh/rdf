require "thread"

class Tracer
  class << self
    attr_accessor :verbose
    alias verbose? verbose

    attr_accessor :stdout

    attr_reader :stdout_mutex

    attr_accessor :display_process_id
    alias display_process_id? display_process_id

    attr_accessor :display_thread_id
    alias display_thread_id? display_thread_id

    attr_accessor :display_c_call
    alias display_c_call? display_c_call
  end

  Tracer::stdout = STDOUT
  Tracer::verbose = false
  Tracer::display_process_id = false
  Tracer::display_thread_id = true
  Tracer::display_c_call = false

  @stdout_mutex = Mutex.new

  EVENT_SYMBOL = {
    "line" => "-",
    "call" => ">",
    "return" => "<",
    "class" => "C",
    "end" => "E",
    "raise" => "^",
    "c-call" => "}",
    "c-return" => "{",
    "unknown" => "?"
  }

  def initialize # :nodoc:
    @threads = Hash.new
    if defined? Thread.main
      @threads[Thread.main.object_id] = 0
    else
      @threads[Thread.current.object_id] = 0
    end

    @get_line_procs = {}

    @filters = []
  end

  def stdout # :nodoc:
    Tracer.stdout
  end

  def on # :nodoc:
    if block_given?
      on
      begin
        yield
      ensure
        off
      end
    else
      set_trace_func method(:trace_func).to_proc
      stdout.print "Trace on\n" if Tracer.verbose?
    end
  end

  def off # :nodoc:
    set_trace_func nil
    stdout.print "Trace off\n" if Tracer.verbose?
  end

  def add_filter(p = proc) # :nodoc:
    @filters.push p
  end

  def set_get_line_procs(file, p = proc) # :nodoc:
    @get_line_procs[file] = p
  end

  def get_line(file, line) # :nodoc:
    if p = @get_line_procs[file]
      return p.call(line)
    end

    unless list = SCRIPT_LINES__[file]
      list = File.readlines(file) rescue []
      SCRIPT_LINES__[file] = list
    end

    if l = list[line - 1]
      l
    else
      "-\n"
    end
  end

  def get_thread_no # :nodoc:
    if no = @threads[Thread.current.object_id]
      no
    else
      @threads[Thread.current.object_id] = @threads.size
    end
  end

  def trace_func(event, file, line, id, binding, klass, *) # :nodoc:
    return if file == __FILE__

    for p in @filters
      return unless p.call event, file, line, id, binding, klass
    end

    return unless Tracer::display_c_call? or
      event != "c-call" && event != "c-return"

    Tracer::stdout_mutex.synchronize do
      if EVENT_SYMBOL[event]
        stdout.printf("<%d>", $$) if Tracer::display_process_id?
        stdout.printf("#%d:", get_thread_no) if Tracer::display_thread_id?
        if line == 0
          source = "?\n"
        else
          source = get_line(file, line)
        end
        stdout.printf("%s:%d:%s:%s: %s",
               file,
               line,
               klass || '',
               EVENT_SYMBOL[event],
               source)
      end
    end

  end

  Single = new


  def Tracer.on
    if block_given?
      Single.on{yield}
    else
      Single.on
    end
  end


  def Tracer.off
    Single.off
  end


  def Tracer.set_get_line_procs(file_name, p = proc)
    Single.set_get_line_procs(file_name, p)
  end


  def Tracer.add_filter(p = proc)
    Single.add_filter(p)
  end
end

SCRIPT_LINES__ = {} unless defined? SCRIPT_LINES__

if $0 == __FILE__

  $0 = ARGV[0]
  ARGV.shift
  Tracer.on
  require $0
else
  count = caller.count {|bt| %r%/rubygems/core_ext/kernel_require\.rb:% !~ bt}
  if (defined?(Gem) and count == 0) or
     (!defined?(Gem) and count <= 1)
    Tracer.on
  end
end
