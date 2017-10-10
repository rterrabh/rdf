require 'optparse'

module Sass::Exec
  class Base
    def initialize(args)
      @args = args
      @options = {}
    end

    def parse!
      begin
        parse
      rescue Exception => e
        at_exit {exit 65} if e.is_a?(Sass::SyntaxError)

        raise e if @options[:trace] || e.is_a?(SystemExit)

        if e.is_a?(Sass::SyntaxError)
          $stderr.puts e.sass_backtrace_str("standard input")
        else
          $stderr.print "#{e.class}: " unless e.class == RuntimeError
          $stderr.puts e.message.to_s
        end
        $stderr.puts "  Use --trace for backtrace."

        exit 1
      end
      exit 0
    end

    def parse
      @opts = OptionParser.new(&method(:set_opts))
      @opts.parse!(@args)

      process_result

      @options
    end

    def to_s
      @opts.to_s
    end

    protected

    def get_line(exception)
      if exception.is_a?(::SyntaxError)
        return (exception.message.scan(/:(\d+)/).first || ["??"]).first
      end
      (exception.backtrace[0].scan(/:(\d+)/).first || ["??"]).first
    end

    def set_opts(opts)
      Sass::Util.abstract(this)
    end

    def encoding_option(opts)
      encoding_desc = if Sass::Util.ruby1_8?
                        'Does not work in Ruby 1.8.'
                      else
                        'Specify the default encoding for input files.'
                      end
      opts.on('-E', '--default-encoding ENCODING', encoding_desc) do |encoding|
        if Sass::Util.ruby1_8?
          $stderr.puts "Specifying the encoding is not supported in ruby 1.8."
          exit 1
        else
          Encoding.default_external = encoding
        end
      end
    end

    def process_result
      input, output = @options[:input], @options[:output]
      args = @args.dup
      input ||=
        begin
          filename = args.shift
          @options[:filename] = filename
          open_file(filename) || $stdin
        end
      @options[:output_filename] = args.shift
      output ||= @options[:output_filename] || $stdout
      @options[:input], @options[:output] = input, output
    end

    COLORS = {:red => 31, :green => 32, :yellow => 33}

    def puts_action(name, color, arg)
      return if @options[:for_engine][:quiet]
      printf color(color, "%11s %s\n"), name, arg
      STDOUT.flush
    end

    def puts(*args)
      return if @options[:for_engine][:quiet]
      Kernel.puts(*args)
    end

    def color(color, str)
      raise "[BUG] Unrecognized color #{color}" unless COLORS[color]

      return str if ENV["TERM"].nil? || ENV["TERM"].empty? || !STDOUT.tty?
      "\e[#{COLORS[color]}m#{str}\e[0m"
    end

    def write_output(text, destination)
      if destination.is_a?(String)
        open_file(destination, 'w') {|file| file.write(text)}
      else
        destination.write(text)
      end
    end

    private

    def open_file(filename, flag = 'r')
      return if filename.nil?
      flag = 'wb' if @options[:unix_newlines] && flag == 'w'
      file = File.open(filename, flag)
      return file unless block_given?
      yield file
      file.close
    end

    def handle_load_error(err)
      dep = err.message[/^no such file to load -- (.*)/, 1]
      raise err if @options[:trace] || dep.nil? || dep.empty?
      $stderr.puts <<MESSAGE
Required dependency #{dep} not found!
    Run "gem install #{dep}" to get it.
  Use --trace for backtrace.
MESSAGE
      exit 1
    end
  end
end
