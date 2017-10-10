
begin
  require 'io/console'
rescue LoadError
end


module Gem::DefaultUserInteraction


  @ui = nil


  def self.ui
    @ui ||= Gem::ConsoleUI.new
  end


  def self.ui=(new_ui)
    @ui = new_ui
  end


  def self.use_ui(new_ui)
    old_ui = @ui
    @ui = new_ui
    yield
  ensure
    @ui = old_ui
  end


  def ui
    Gem::DefaultUserInteraction.ui
  end


  def ui=(new_ui)
    Gem::DefaultUserInteraction.ui = new_ui
  end


  def use_ui(new_ui, &block)
    Gem::DefaultUserInteraction.use_ui(new_ui, &block)
  end

end


module Gem::UserInteraction

  include Gem::DefaultUserInteraction


  def alert statement, question = nil
    ui.alert statement, question
  end


  def alert_error statement, question = nil
    ui.alert_error statement, question
  end


  def alert_warning statement, question = nil
    ui.alert_warning statement, question
  end


  def ask question
    ui.ask question
  end


  def ask_for_password prompt
    ui.ask_for_password prompt
  end


  def ask_yes_no question, default = nil
    ui.ask_yes_no question, default
  end


  def choose_from_list question, list
    ui.choose_from_list question, list
  end


  def say statement = ''
    ui.say statement
  end


  def terminate_interaction exit_code = 0
    ui.terminate_interaction exit_code
  end


  def verbose msg = nil
    say(msg || yield) if Gem.configuration.really_verbose
  end
end


class Gem::StreamUI


  attr_reader :ins


  attr_reader :outs


  attr_reader :errs


  def initialize(in_stream, out_stream, err_stream=STDERR, usetty=true)
    @ins = in_stream
    @outs = out_stream
    @errs = err_stream
    @usetty = usetty
  end


  def tty?
    if RUBY_VERSION < '1.9.3' and RUBY_PLATFORM =~ /mingw|mswin/ then
      @usetty
    else
      @usetty && @ins.tty?
    end
  end


  def backtrace exception
    return unless Gem.configuration.backtrace

    @errs.puts "\t#{exception.backtrace.join "\n\t"}"
  end


  def choose_from_list(question, list)
    @outs.puts question

    list.each_with_index do |item, index|
      @outs.puts " #{index+1}. #{item}"
    end

    @outs.print "> "
    @outs.flush

    result = @ins.gets

    return nil, nil unless result

    result = result.strip.to_i - 1
    return list[result], result
  end


  def ask_yes_no(question, default=nil)
    unless tty? then
      if default.nil? then
        raise Gem::OperationNotSupportedError,
              "Not connected to a tty and no default specified"
      else
        return default
      end
    end

    default_answer = case default
                     when nil
                       'yn'
                     when true
                       'Yn'
                     else
                       'yN'
                     end

    result = nil

    while result.nil? do
      result = case ask "#{question} [#{default_answer}]"
               when /^y/i then true
               when /^n/i then false
               when /^$/  then default
               else            nil
               end
    end

    return result
  end


  def ask(question)
    return nil if not tty?

    @outs.print(question + "  ")
    @outs.flush

    result = @ins.gets
    result.chomp! if result
    result
  end


  def ask_for_password(question)
    return nil if not tty?

    @outs.print(question, "  ")
    @outs.flush

    password = _gets_noecho
    @outs.puts
    password.chomp! if password
    password
  end

  if IO.method_defined?(:noecho) then
    def _gets_noecho
      @ins.noecho {@ins.gets}
    end
  elsif Gem.win_platform?
    def _gets_noecho
      require "Win32API"
      password = ''

      while char = Win32API.new("crtdll", "_getch", [ ], "L").Call do
        break if char == 10 || char == 13 # received carriage return or newline
        if char == 127 || char == 8 # backspace and delete
          password.slice!(-1, 1)
        else
          password << char.chr
        end
      end
      password
    end
  else
    def _gets_noecho
      system "stty -echo"
      begin
        @ins.gets
      ensure
        system "stty echo"
      end
    end
  end


  def say(statement="")
    @outs.puts statement
  end


  def alert(statement, question=nil)
    @outs.puts "INFO:  #{statement}"
    ask(question) if question
  end


  def alert_warning(statement, question=nil)
    @errs.puts "WARNING:  #{statement}"
    ask(question) if question
  end


  def alert_error(statement, question=nil)
    @errs.puts "ERROR:  #{statement}"
    ask(question) if question
  end


  def debug(statement)
    @errs.puts statement
  end


  def terminate_interaction(status = 0)
    close
    raise Gem::SystemExitException, status
  end

  def close
  end


  def progress_reporter(*args)
    if self.kind_of?(Gem::SilentUI)
      return SilentProgressReporter.new(@outs, *args)
    end

    case Gem.configuration.verbose
    when nil, false
      SilentProgressReporter.new(@outs, *args)
    when true
      SimpleProgressReporter.new(@outs, *args)
    else
      VerboseProgressReporter.new(@outs, *args)
    end
  end


  class SilentProgressReporter


    attr_reader :count


    def initialize(out_stream, size, initial_message, terminal_message = nil)
    end


    def updated(message)
    end


    def done
    end
  end


  class SimpleProgressReporter

    include Gem::DefaultUserInteraction


    attr_reader :count


    def initialize(out_stream, size, initial_message,
                   terminal_message = "complete")
      @out = out_stream
      @total = size
      @count = 0
      @terminal_message = terminal_message

      @out.puts initial_message
    end


    def updated(message)
      @count += 1
      @out.print "."
      @out.flush
    end


    def done
      @out.puts "\n#{@terminal_message}"
    end

  end


  class VerboseProgressReporter

    include Gem::DefaultUserInteraction


    attr_reader :count


    def initialize(out_stream, size, initial_message,
                   terminal_message = 'complete')
      @out = out_stream
      @total = size
      @count = 0
      @terminal_message = terminal_message

      @out.puts initial_message
    end


    def updated(message)
      @count += 1
      @out.puts "#{@count}/#{@total}: #{message}"
    end


    def done
      @out.puts @terminal_message
    end
  end


  def download_reporter(*args)
    if self.kind_of?(Gem::SilentUI)
      return SilentDownloadReporter.new(@outs, *args)
    end

    case Gem.configuration.verbose
    when nil, false
      SilentDownloadReporter.new(@outs, *args)
    else
      VerboseDownloadReporter.new(@outs, *args)
    end
  end


  class SilentDownloadReporter


    def initialize(out_stream, *args)
    end


    def fetch(filename, filesize)
    end


    def update(current)
    end


    def done
    end
  end


  class VerboseDownloadReporter


    attr_reader :file_name


    attr_reader :total_bytes


    attr_reader :progress


    def initialize(out_stream, *args)
      @out = out_stream
      @progress = 0
    end


    def fetch(file_name, total_bytes)
      @file_name = file_name
      @total_bytes = total_bytes.to_i
      @units = @total_bytes.zero? ? 'B' : '%'

      update_display(false)
    end


    def update(bytes)
      new_progress = if @units == 'B' then
                       bytes
                     else
                       ((bytes.to_f * 100) / total_bytes.to_f).ceil
                     end

      return if new_progress == @progress

      @progress = new_progress
      update_display
    end


    def done
      @progress = 100 if @units == '%'
      update_display(true, true)
    end

    private

    def update_display(show_progress = true, new_line = false) # :nodoc:
      return unless @out.tty?

      if show_progress then
        @out.print "\rFetching: %s (%3d%s)" % [@file_name, @progress, @units]
      else
        @out.print "Fetching: %s" % @file_name
      end
      @out.puts if new_line
    end
  end
end


class Gem::ConsoleUI < Gem::StreamUI


  def initialize
    super STDIN, STDOUT, STDERR, true
  end
end


class Gem::SilentUI < Gem::StreamUI


  def initialize
    reader, writer = nil, nil

    begin
      reader = File.open('/dev/null', 'r')
      writer = File.open('/dev/null', 'w')
    rescue Errno::ENOENT
      reader = File.open('nul', 'r')
      writer = File.open('nul', 'w')
    end

    super reader, writer, writer, false
  end

  def close
    super
    @ins.close
    @outs.close
  end

  def download_reporter(*args) # :nodoc:
    SilentDownloadReporter.new(@outs, *args)
  end

  def progress_reporter(*args) # :nodoc:
    SilentProgressReporter.new(@outs, *args)
  end
end

