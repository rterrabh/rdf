module Pod
  module Executable
    def executable(name)
      #nodyna <define_method-2695> <DM COMPLEX (events)>
      define_method(name) do |*command|
        Executable.execute_command(name, Array(command).flatten, false)
      end

      #nodyna <define_method-2696> <DM COMPLEX (events)>
      define_method(name.to_s + '!') do |*command|
        Executable.execute_command(name, Array(command).flatten, true)
      end
    end

    def self.execute_command(executable, command, raise_on_failure = true)
      bin = which(executable)
      raise Informative, "Unable to locate the executable `#{executable}`" unless bin

      command = command.map(&:to_s)
      full_command = "#{bin} #{command.join(' ')}"

      if Config.instance.verbose?
        UI.message("$ #{full_command}")
        stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
      else
        stdout, stderr = Indenter.new, Indenter.new
      end

      status = popen3(bin, command, stdout, stderr)
      stdout, stderr = stdout.join, stderr.join
      output = stdout + stderr
      unless status.success?
        if raise_on_failure
          raise Informative, "#{full_command}\n\n#{output}"
        else
          UI.message("[!] Failed: #{full_command}".red)
        end
      end

      output
    end

    def self.which(program)
      program = program.to_s
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        bin = File.expand_path(program, path)
        if File.file?(bin) && File.executable?(bin)
          return bin
        end
      end
      nil
    end

    def self.capture_command(executable, command, capture: :merge)
      bin = which(executable)
      raise Informative, "Unable to locate the executable `#{executable}`" unless bin

      require 'open3'
      command = command.map(&:to_s)
      case capture
      when :merge then Open3.capture2e(bin, *command)
      when :both then Open3.capture3(bin, *command)
      when :out then Open3.capture2(bin, *command)
      when :err then Open3.capture3(bin, *command).drop(1)
      when :none then Open3.capture2(bin, *command).last
      end
    end

    private

    def self.popen3(bin, command, stdout, stderr)
      require 'open3'
      Open3.popen3(bin, *command) do |i, o, e, t|
        reader(o, stdout)
        reader(e, stderr)
        i.close

        status = t.value

        o.flush
        e.flush
        sleep(0.01)

        status
      end
    end

    def self.reader(input, output)
      Thread.new do
        buf = ''
        begin
          loop do
            buf << input.readpartial(4096)
            loop do
              string, separator, buf = buf.partition(/[\r\n]/)
              if separator.empty?
                buf = string
                break
              end
              output << (string << separator)
            end
          end
        rescue EOFError
          output << (buf << $/) unless buf.empty?
        end
      end
    end


    class Indenter < ::Array
      attr_accessor :indent

      attr_accessor :io

      def initialize(io = nil)
        @io = io
        @indent = ' ' * UI.indentation_level
      end

      def <<(value)
        super
        io << "#{ indent }#{ value }" if io
      end
    end
  end
end
