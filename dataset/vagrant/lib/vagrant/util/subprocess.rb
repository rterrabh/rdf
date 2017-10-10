require 'thread'

require 'childprocess'
require 'log4r'

require 'vagrant/util/io'
require 'vagrant/util/platform'
require 'vagrant/util/safe_chdir'
require 'vagrant/util/which'

module Vagrant
  module Util
    class Subprocess
      def self.execute(*command, &block)
        new(*command).execute(&block)
      end

      def initialize(*command)
        @options = command.last.is_a?(Hash) ? command.pop : {}
        @command = command.dup
        @command = @command.map { |s| s.encode(Encoding.default_external) }
        @command[0] = Which.which(@command[0]) if !File.file?(@command[0])
        if !@command[0]
          raise Errors::CommandUnavailableWindows, file: command[0] if Platform.windows?
          raise Errors::CommandUnavailable, file: command[0]
        end

        @logger  = Log4r::Logger.new("vagrant::util::subprocess")
      end

      def execute
        timeout = @options[:timeout]

        workdir = @options[:workdir] || Dir.pwd

        notify  = @options[:notify] || []
        notify  = [notify] if !notify.is_a?(Array)
        if notify.empty? && block_given?
          message = "A list of notify subscriptions must be given if a block is given"
          raise ArgumentError, message
        end

        notify_table = {}
        notify_table[:stderr] = notify.include?(:stderr)
        notify_table[:stdout] = notify.include?(:stdout)
        notify_stdin  = notify.include?(:stdin)

        @logger.info("Starting process: #{@command.inspect}")
        process = ChildProcess.build(*@command)

        stdout, stdout_writer = ::IO.pipe
        stderr, stderr_writer = ::IO.pipe
        process.io.stdout = stdout_writer
        process.io.stderr = stderr_writer
        process.duplex = true

        if Vagrant.in_installer?
          installer_dir = ENV["VAGRANT_INSTALLER_EMBEDDED_DIR"].to_s.downcase

          if Platform.darwin?
            if @command[0].downcase.include?(installer_dir)
              @logger.info("Command in the installer. Specifying DYLD_LIBRARY_PATH...")
              process.environment["DYLD_LIBRARY_PATH"] =
                "#{installer_dir}/lib:#{ENV["DYLD_LIBRARY_PATH"]}"
            else
              @logger.debug("Command not in installer, not touching env vars.")
            end

            if File.setuid?(@command[0]) || File.setgid?(@command[0])
              @logger.info("Command is setuid/setgid, clearing DYLD_LIBRARY_PATH")
              process.environment["DYLD_LIBRARY_PATH"] = ""
            end
          end

          internal = [installer_dir, Vagrant.user_data_path.to_s.downcase].
            any? { |path| @command[0].downcase.include?(path) }
          if !internal
            @logger.info("Command not in installer, restoring original environment...")
            jailbreak(process.environment)
          end
        else
          @logger.info("Vagrant not running in installer, restoring original environment...")
          jailbreak(process.environment)
        end

        if @options[:env]
          @options[:env].each do |k, v|
            process.environment[k] = v
          end
        end

        begin
          SafeChdir.safe_chdir(workdir) do
            process.start
          end
        rescue ChildProcess::LaunchError => ex
          raise LaunchError.new(ex.message)
        end

        process.io.stdin.sync = true

        if RUBY_PLATFORM != "java"
          stdout_writer.close
          stderr_writer.close
        end

        io_data = { stdout: "", stderr: "" }

        start_time = Time.now.to_i

        @logger.debug("Selecting on IO")
        while true
          writers = notify_stdin ? [process.io.stdin] : []
          results = ::IO.select([stdout, stderr], writers, nil, 0.1)
          results ||= []
          readers = results[0]
          writers = results[1]

          raise TimeoutExceeded, process.pid if timeout && (Time.now.to_i - start_time) > timeout

          if readers && !readers.empty?
            readers.each do |r|
              data = IO.read_until_block(r)

              next if data.empty?

              io_name = r == stdout ? :stdout : :stderr
              @logger.debug("#{io_name}: #{data.chomp}")

              io_data[io_name] += data
              yield io_name, data if block_given? && notify_table[io_name]
            end
          end

          break if process.exited?

          if writers && !writers.empty?
            yield :stdin, process.io.stdin if block_given?
          end
        end

        begin
          remaining = (timeout || 32000) - (Time.now.to_i - start_time)
          remaining = 0 if remaining < 0
          @logger.debug("Waiting for process to exit. Remaining to timeout: #{remaining}")

          process.poll_for_exit(remaining)
        rescue ChildProcess::TimeoutError
          raise TimeoutExceeded, process.pid
        end

        @logger.debug("Exit status: #{process.exit_code}")

        [stdout, stderr].each do |io|
          extra_data = IO.read_until_block(io)
          next if extra_data == ""

          io_name = io == stdout ? :stdout : :stderr
          io_data[io_name] += extra_data
          @logger.debug("#{io_name}: #{extra_data.chomp}")

          yield io_name, extra_data if block_given? && notify_table[io_name]
        end

        if RUBY_PLATFORM == "java"
          stdout_writer.close
          stderr_writer.close
        end

        return Result.new(process.exit_code, io_data[:stdout], io_data[:stderr])
      ensure
        if process && process.alive?
          process.stop(2)
        end
      end

      protected

      class LaunchError < StandardError; end

      class TimeoutExceeded < StandardError
        attr_reader :pid

        def initialize(pid)
          super()
          @pid = pid
        end
      end

      class Result
        attr_reader :exit_code
        attr_reader :stdout
        attr_reader :stderr

        def initialize(exit_code, stdout, stderr)
          @exit_code = exit_code
          @stdout    = stdout
          @stderr    = stderr
        end
      end

      private

      def jailbreak(env = {})
        return if ENV.key?("VAGRANT_SKIP_SUBPROCESS_JAILBREAK")

        env.replace(::Bundler::ORIGINAL_ENV) if defined?(::Bundler::ORIGINAL_ENV)
        env.merge!(Vagrant.original_env)

        env["MANPATH"] = ENV["BUNDLE_ORIG_MANPATH"]

        ENV.each do |k,_|
          env[k] = nil if k[0,7] == "BUNDLE_"
        end

        if ENV.key?("RUBYOPT")
          env["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
        end

        nil
      end
    end
  end
end
