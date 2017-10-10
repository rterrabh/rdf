

module Benchmark

  BENCHMARK_VERSION = "2002-04-25" # :nodoc:


  def benchmark(caption = "", label_width = nil, format = nil, *labels) # :yield: report
    sync = STDOUT.sync
    STDOUT.sync = true
    label_width ||= 0
    label_width += 1
    format ||= FORMAT
    print ' '*label_width + caption unless caption.empty?
    report = Report.new(label_width, format)
    results = yield(report)
    Array === results and results.grep(Tms).each {|t|
      print((labels.shift || t.label || "").ljust(label_width), t.format(format))
    }
    report.list
  ensure
    STDOUT.sync = sync unless sync.nil?
  end



  def bm(label_width = 0, *labels, &blk) # :yield: report
    benchmark(CAPTION, label_width, FORMAT, *labels, &blk)
  end


  def bmbm(width = 0) # :yield: job
    job = Job.new(width)
    yield(job)
    width = job.width + 1
    sync = STDOUT.sync
    STDOUT.sync = true

    puts 'Rehearsal '.ljust(width+CAPTION.length,'-')
    ets = job.list.inject(Tms.new) { |sum,(label,item)|
      print label.ljust(width)
      res = Benchmark.measure(&item)
      print res.format
      sum + res
    }.format("total: %tsec")
    print " #{ets}\n\n".rjust(width+CAPTION.length+2,'-')

    print ' '*width + CAPTION
    job.list.map { |label,item|
      GC.start
      print label.ljust(width)
      Benchmark.measure(label, &item).tap { |res| print res }
    }
  ensure
    STDOUT.sync = sync unless sync.nil?
  end

  case
  when defined?(Process::CLOCK_MONOTONIC)
    BENCHMARK_CLOCK = Process::CLOCK_MONOTONIC
  else
    BENCHMARK_CLOCK = Process::CLOCK_REALTIME
  end

  def measure(label = "") # :yield:
    t0, r0 = Process.times, Process.clock_gettime(BENCHMARK_CLOCK)
    yield
    t1, r1 = Process.times, Process.clock_gettime(BENCHMARK_CLOCK)
    Benchmark::Tms.new(t1.utime  - t0.utime,
                       t1.stime  - t0.stime,
                       t1.cutime - t0.cutime,
                       t1.cstime - t0.cstime,
                       r1 - r0,
                       label)
  end

  def realtime # :yield:
    r0 = Process.clock_gettime(BENCHMARK_CLOCK)
    yield
    Process.clock_gettime(BENCHMARK_CLOCK) - r0
  end

  module_function :benchmark, :measure, :realtime, :bm, :bmbm

  class Job # :nodoc:
    def initialize(width)
      @width = width
      @list = []
    end

    def item(label = "", &blk) # :yield:
      raise ArgumentError, "no block" unless block_given?
      label = label.to_s
      w = label.length
      @width = w if @width < w
      @list << [label, blk]
      self
    end

    alias report item

    attr_reader :list

    attr_reader :width
  end

  class Report # :nodoc:
    def initialize(width = 0, format = nil)
      @width, @format, @list = width, format, []
    end

    def item(label = "", *format, &blk) # :yield:
      print label.to_s.ljust(@width)
      @list << res = Benchmark.measure(label, &blk)
      print res.format(@format, *format)
      res
    end

    alias report item

    attr_reader :list
  end



  class Tms

    CAPTION = "      user     system      total        real\n"

    FORMAT = "%10.6u %10.6y %10.6t %10.6r\n"

    attr_reader :utime

    attr_reader :stime

    attr_reader :cutime

    attr_reader :cstime

    attr_reader :real

    attr_reader :total

    attr_reader :label

    def initialize(utime = 0.0, stime = 0.0, cutime = 0.0, cstime = 0.0, real = 0.0, label = nil)
      @utime, @stime, @cutime, @cstime, @real, @label = utime, stime, cutime, cstime, real, label.to_s
      @total = @utime + @stime + @cutime + @cstime
    end

    def add(&blk) # :yield:
      self + Benchmark.measure(&blk)
    end

    def add!(&blk)
      t = Benchmark.measure(&blk)
      @utime  = utime + t.utime
      @stime  = stime + t.stime
      @cutime = cutime + t.cutime
      @cstime = cstime + t.cstime
      @real   = real + t.real
      self
    end

    def +(other); memberwise(:+, other) end

    def -(other); memberwise(:-, other) end

    def *(x); memberwise(:*, x) end

    def /(x); memberwise(:/, x) end

    def format(format = nil, *args)
      str = (format || FORMAT).dup
      str.gsub!(/(%[-+.\d]*)n/) { "#{$1}s" % label }
      str.gsub!(/(%[-+.\d]*)u/) { "#{$1}f" % utime }
      str.gsub!(/(%[-+.\d]*)y/) { "#{$1}f" % stime }
      str.gsub!(/(%[-+.\d]*)U/) { "#{$1}f" % cutime }
      str.gsub!(/(%[-+.\d]*)Y/) { "#{$1}f" % cstime }
      str.gsub!(/(%[-+.\d]*)t/) { "#{$1}f" % total }
      str.gsub!(/(%[-+.\d]*)r/) { "(#{$1}f)" % real }
      format ? str % args : str
    end

    def to_s
      format
    end

    def to_a
      [@label, @utime, @stime, @cutime, @cstime, @real]
    end

    protected

    def memberwise(op, x)
      case x
      when Benchmark::Tms
        Benchmark::Tms.new(utime.__send__(op, x.utime),
                           stime.__send__(op, x.stime),
                           cutime.__send__(op, x.cutime),
                           cstime.__send__(op, x.cstime),
                           real.__send__(op, x.real)
                           )
      else
        Benchmark::Tms.new(utime.__send__(op, x),
                           stime.__send__(op, x),
                           cutime.__send__(op, x),
                           cstime.__send__(op, x),
                           real.__send__(op, x)
                           )
      end
    end
  end

  CAPTION = Benchmark::Tms::CAPTION

  FORMAT = Benchmark::Tms::FORMAT
end
