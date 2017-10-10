
require 'monitor'

class Logger
  VERSION = "1.2.7"
  _, name, rev = %w$Id$
  if name
    name = name.chomp(",v")
  else
    name = File.basename(__FILE__)
  end
  rev ||= "v#{VERSION}"
  ProgName = "#{name}/#{rev}"

  class Error < RuntimeError # :nodoc:
  end
  class ShiftingError < Error # :nodoc:
  end

  module Severity
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    FATAL = 4
    UNKNOWN = 5
  end
  include Severity

  attr_accessor :level

  attr_accessor :progname

  def datetime_format=(datetime_format)
    @default_formatter.datetime_format = datetime_format
  end

  def datetime_format
    @default_formatter.datetime_format
  end

  attr_accessor :formatter

  alias sev_threshold level
  alias sev_threshold= level=

  def debug?; @level <= DEBUG; end

  def info?; @level <= INFO; end

  def warn?; @level <= WARN; end

  def error?; @level <= ERROR; end

  def fatal?; @level <= FATAL; end

  def initialize(logdev, shift_age = 0, shift_size = 1048576)
    @progname = nil
    @level = DEBUG
    @default_formatter = Formatter.new
    @formatter = nil
    @logdev = nil
    if logdev
      @logdev = LogDevice.new(logdev, :shift_age => shift_age,
        :shift_size => shift_size)
    end
  end

  def add(severity, message = nil, progname = nil, &block)
    severity ||= UNKNOWN
    if @logdev.nil? or severity < @level
      return true
    end
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    @logdev.write(
      format_message(format_severity(severity), Time.now, progname, message))
    true
  end
  alias log add

  def <<(msg)
    unless @logdev.nil?
      @logdev.write(msg)
    end
  end

  def debug(progname = nil, &block)
    add(DEBUG, nil, progname, &block)
  end

  def info(progname = nil, &block)
    add(INFO, nil, progname, &block)
  end

  def warn(progname = nil, &block)
    add(WARN, nil, progname, &block)
  end

  def error(progname = nil, &block)
    add(ERROR, nil, progname, &block)
  end

  def fatal(progname = nil, &block)
    add(FATAL, nil, progname, &block)
  end

  def unknown(progname = nil, &block)
    add(UNKNOWN, nil, progname, &block)
  end

  def close
    @logdev.close if @logdev
  end

private

  SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

  def format_severity(severity)
    SEV_LABEL[severity] || 'ANY'
  end

  def format_message(severity, datetime, progname, msg)
    (@formatter || @default_formatter).call(severity, datetime, progname, msg)
  end


  class Formatter
    Format = "%s, [%s#%d] %5s -- %s: %s\n"

    attr_accessor :datetime_format

    def initialize
      @datetime_format = nil
    end

    def call(severity, time, progname, msg)
      Format % [severity[0..0], format_datetime(time), $$, severity, progname,
        msg2str(msg)]
    end

  private

    def format_datetime(time)
      time.strftime(@datetime_format || "%Y-%m-%dT%H:%M:%S.%6N ".freeze)
    end

    def msg2str(msg)
      case msg
      when ::String
        msg
      when ::Exception
        "#{ msg.message } (#{ msg.class })\n" <<
          (msg.backtrace || []).join("\n")
      else
        msg.inspect
      end
    end
  end

  module Period
    module_function

    SiD = 24 * 60 * 60

    def next_rotate_time(now, shift_age)
      case shift_age
      when /^daily$/
        t = Time.mktime(now.year, now.month, now.mday) + SiD
      when /^weekly$/
        t = Time.mktime(now.year, now.month, now.mday) + SiD * (7 - now.wday)
      when /^monthly$/
        t = Time.mktime(now.year, now.month, 1) + SiD * 31
        mday = (1 if t.mday > 1)
      else
        return now
      end
      if mday or t.hour.nonzero? or t.min.nonzero? or t.sec.nonzero?
        t = Time.mktime(t.year, t.month, mday || (t.mday + (t.hour > 12 ? 1 : 0)))
      end
      t
    end

    def previous_period_end(now, shift_age)
      case shift_age
      when /^daily$/
        t = Time.mktime(now.year, now.month, now.mday) - SiD / 2
      when /^weekly$/
        t = Time.mktime(now.year, now.month, now.mday) - (SiD * (now.wday + 1) + SiD / 2)
      when /^monthly$/
        t = Time.mktime(now.year, now.month, 1) - SiD / 2
      else
        return now
      end
      Time.mktime(t.year, t.month, t.mday, 23, 59, 59)
    end
  end

  class LogDevice
    include Period

    attr_reader :dev
    attr_reader :filename

    class LogDeviceMutex
      include MonitorMixin
    end

    def initialize(log = nil, opt = {})
      @dev = @filename = @shift_age = @shift_size = nil
      @mutex = LogDeviceMutex.new
      if log.respond_to?(:write) and log.respond_to?(:close)
        @dev = log
      else
        @dev = open_logfile(log)
        @dev.sync = true
        @filename = log
        @shift_age = opt[:shift_age] || 7
        @shift_size = opt[:shift_size] || 1048576
        @next_rotate_time = next_rotate_time(Time.now, @shift_age) unless @shift_age.is_a?(Integer)
      end
    end

    def write(message)
      begin
        @mutex.synchronize do
          if @shift_age and @dev.respond_to?(:stat)
            begin
              check_shift_log
            rescue
              warn("log shifting failed. #{$!}")
            end
          end
          begin
            @dev.write(message)
          rescue
            warn("log writing failed. #{$!}")
          end
        end
      rescue Exception => ignored
        warn("log writing failed. #{ignored}")
      end
    end

    def close
      begin
        @mutex.synchronize do
          @dev.close rescue nil
        end
      rescue Exception
        @dev.close rescue nil
      end
    end

  private

    def open_logfile(filename)
      begin
        open(filename, (File::WRONLY | File::APPEND))
      rescue Errno::ENOENT
        create_logfile(filename)
      end
    end

    def create_logfile(filename)
      begin
        logdev = open(filename, (File::WRONLY | File::APPEND | File::CREAT | File::EXCL))
        logdev.flock(File::LOCK_EX)
        logdev.sync = true
        add_log_header(logdev)
        logdev.flock(File::LOCK_UN)
      rescue Errno::EEXIST
        logdev = open_logfile(filename)
        logdev.sync = true
      end
      logdev
    end

    def add_log_header(file)
      file.write(
        "# Logfile created on %s by %s\n" % [Time.now.to_s, Logger::ProgName]
      ) if file.size == 0
    end

    def check_shift_log
      if @shift_age.is_a?(Integer)
        if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)
          lock_shift_log { shift_log_age }
        end
      else
        now = Time.now
        if now >= @next_rotate_time
          @next_rotate_time = next_rotate_time(now, @shift_age)
          lock_shift_log { shift_log_period(previous_period_end(now, @shift_age)) }
        end
      end
    end

    if /mswin|mingw/ =~ RUBY_PLATFORM
      def lock_shift_log
        yield
      end
    else
      def lock_shift_log
        retry_limit = 8
        retry_sleep = 0.1
        begin
          File.open(@filename, File::WRONLY | File::APPEND) do |lock|
            lock.flock(File::LOCK_EX) # inter-process locking. will be unlocked at closing file
            if File.identical?(@filename, lock) and File.identical?(lock, @dev)
              yield # log shifting
            else
              @dev.close rescue nil
              @dev = open_logfile(@filename)
              @dev.sync = true
            end
          end
        rescue Errno::ENOENT
          if retry_limit <= 0
            warn("log rotation inter-process lock failed. #{$!}")
          else
            sleep retry_sleep
            retry_limit -= 1
            retry_sleep *= 2
            retry
          end
        end
      rescue
        warn("log rotation inter-process lock failed. #{$!}")
      end
    end

    def shift_log_age
      (@shift_age-3).downto(0) do |i|
        if FileTest.exist?("#{@filename}.#{i}")
          File.rename("#{@filename}.#{i}", "#{@filename}.#{i+1}")
        end
      end
      @dev.close rescue nil
      File.rename("#{@filename}", "#{@filename}.0")
      @dev = create_logfile(@filename)
      return true
    end

    def shift_log_period(period_end)
      postfix = period_end.strftime("%Y%m%d") # YYYYMMDD
      age_file = "#{@filename}.#{postfix}"
      if FileTest.exist?(age_file)
        idx = 0
        while idx < 100
          idx += 1
          age_file = "#{@filename}.#{postfix}.#{idx}"
          break unless FileTest.exist?(age_file)
        end
      end
      @dev.close rescue nil
      File.rename("#{@filename}", age_file)
      @dev = create_logfile(@filename)
      return true
    end
  end
end
