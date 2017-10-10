require "delegate"
require "io/console"
require "thread"

require "log4r"

require "vagrant/util/platform"
require "vagrant/util/safe_puts"

module Vagrant
  module UI
    class Interface
      attr_accessor :opts

      attr_accessor :stdin

      attr_accessor :stdout

      attr_accessor :stderr

      def initialize
        @logger   = Log4r::Logger.new("vagrant::ui::interface")
        @opts     = {}

        @stdin  = $stdin
        @stdout = $stdout
        @stderr = $stderr
      end

      def initialize_copy(original)
        super
        @opts = original.opts.dup
      end

      [:ask, :detail, :warn, :error, :info, :output, :success].each do |method|
        #nodyna <define_method-3084> <DM MODERATE (array)>
        define_method(method) do |message, *opts|
          begin
            @logger.info { "#{method}: #{message}" }
          rescue ThreadError
            Thread.new do
              @logger.info { "#{method}: #{message}" }
            end.join
          end
        end
      end

      [:clear_line, :report_progress].each do |method|
        #nodyna <define_method-3085> <DM MODERATE (array)>
        define_method(method) { |*args| }
      end

      def color?
        return false
      end

      def machine(type, *data)
        @logger.info("Machine: #{type} #{data.inspect}")
      end
    end

    class Silent < Interface
      def ask(*args)
        super

        raise Errors::UIExpectsTTY
      end
    end

    class MachineReadable < Interface
      include Util::SafePuts

      def initialize
        super

        @lock = Mutex.new
      end

      def ask(*args)
        super

        raise Errors::UIExpectsTTY
      end

      def machine(type, *data)
        opts = {}
        opts = data.pop if data.last.kind_of?(Hash)

        target = opts[:target] || ""

        data.each_index do |i|
          data[i] = data[i].to_s.dup
          data[i].gsub!(",", "%!(VAGRANT_COMMA)")
          data[i].gsub!("\n", "\\n")
          data[i].gsub!("\r", "\\r")
        end

        @lock.synchronize do
          safe_puts("#{Time.now.utc.to_i},#{target},#{type},#{data.join(",")}")
        end
      end
    end

    class Basic < Interface
      include Util::SafePuts

      def initialize
        super

        @lock = Mutex.new
      end

      [:detail, :info, :warn, :error, :output, :success].each do |method|
        #nodyna <class_eval-3086> <CE MODERATE (define methods)>
        class_eval <<-CODE
          def #{method}(message, *args)
            super(message)
            say(#{method.inspect}, message, *args)
          end
        CODE
      end

      def ask(message, opts=nil)
        super(message)

        raise Errors::UIExpectsTTY if !@stdin.tty? && !Vagrant::Util::Platform.cygwin?

        opts ||= {}
        opts[:echo]     = true  if !opts.key?(:echo)
        opts[:new_line] = false if !opts.key?(:new_line)
        opts[:prefix]   = false if !opts.key?(:prefix)

        say(:info, message, opts)

        input = nil
        if opts[:echo] || !@stdin.respond_to?(:noecho)
          input = @stdin.gets
        else
          begin
            input = @stdin.noecho(&:gets)

            say(:info, "\n", opts)
          rescue Errno::EBADF
            say(:info, "\n#{I18n.t("vagrant.stdin_cant_hide_input")}\n ", opts)

            input = ask(message, opts.merge(echo: true))
          end
        end

        (input || "").chomp
      end

      def report_progress(progress, total, show_parts=true)
        if total && total > 0
          percent = (progress.to_f / total.to_f) * 100
          line    = "Progress: #{percent.to_i}%"
          line   << " (#{progress} / #{total})" if show_parts
        else
          line    = "Progress: #{progress}"
        end

        info(line, new_line: false)
      end

      def clear_line
        reset = "\r\033[K"

        info(reset, new_line: false)
      end

      def say(type, message, **opts)
        defaults = { new_line: true, prefix: true }
        opts     = defaults.merge(@opts).merge(opts)

        return if type == :detail && opts[:hide_detail]

        printer = opts[:new_line] ? :puts : :print

        channel = type == :error || opts[:channel] == :error ? @stderr : @stdout

        Thread.new do
          @lock.synchronize do
            safe_puts(format_message(type, message, **opts),
                      io: channel, printer: printer)
          end
        end.join
      end

      def format_message(type, message, **opts)
        message
      end
    end

    class Prefixed < Interface
      OUTPUT_PREFIX = "==> "

      def initialize(ui, prefix)
        super()

        @prefix = prefix
        @ui     = ui
      end

      def initialize_copy(original)
        super
        #nodyna <instance_variable_get-3087> <IVG COMPLEX (change-prone variables)>
        @ui = original.instance_variable_get(:@ui).dup
      end

      [:ask, :detail, :info, :warn, :error, :output, :success].each do |method|
        #nodyna <class_eval-3088> <CE MODERATE (define methods)>
        class_eval <<-CODE
          def #{method}(message, *args, **opts)
            super(message)
            if !@ui.opts.key?(:bold) && !opts.key?(:bold)
              opts[:bold] = #{method.inspect} != :detail && \
            end
            @ui.#{method}(format_message(#{method.inspect}, message, **opts), *args, **opts)
          end
        CODE
      end

      [:clear_line, :report_progress].each do |method|
        #nodyna <define_method-3089> <DM MODERATE (array)>
        #nodyna <send-3090> <SD MODERATE (change-prone variables)>
        define_method(method) { |*args| @ui.send(method, *args) }
      end

      def machine(type, *data)
        opts = {}
        opts = data.pop if data.last.is_a?(Hash)
        opts[:target] = @prefix
        data << opts
        @ui.machine(type, *data)
      end

      def opts
        @ui.opts
      end

      def format_message(type, message, **opts)
        opts = self.opts.merge(opts)

        prefix = ""
        if !opts.key?(:prefix) || opts[:prefix]
          prefix = OUTPUT_PREFIX
          prefix = " " * OUTPUT_PREFIX.length if \
            type == :detail || type == :ask || opts[:prefix_spaces]
        end

        return message if prefix.empty?

        target = @prefix
        target = opts[:target] if opts.key?(:target)

        lines = [message]
        lines = message.split("\n") if message != ""

        lines.map do |line|
          "#{prefix}#{target}: #{line}"
        end.join("\n")
      end
    end

    class Colored < Basic
      COLORS = {
        red:     31,
        green:   32,
        yellow:  33,
        blue:    34,
        magenta: 35,
        cyan:    36,
        white:   37,
      }

      def color?
        return true
      end

      def format_message(type, message, **opts)
        message = super

        opts = @opts.merge(opts)

        opts[:color] = :red if type == :error
        opts[:color] = :green if type == :success
        opts[:color] = :yellow if type == :warn

        bold  = !!opts[:bold]
        colorseq = "#{bold ? 1 : 0 }"
        if opts[:color] && opts[:color] != :default
          color = COLORS[opts[:color]]
          colorseq += ";#{color}"
        end

        "\033[#{colorseq}m#{message}\033[0m"
      end
    end
  end
end
