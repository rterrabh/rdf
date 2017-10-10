require "uri"

require "log4r"

require "vagrant/util/busy"
require "vagrant/util/platform"
require "vagrant/util/subprocess"

module Vagrant
  module Util
    class Downloader
      USER_AGENT = "Vagrant/#{VERSION}"

      attr_reader :source
      attr_reader :destination

      def initialize(source, destination, options=nil)
        options     ||= {}

        @logger      = Log4r::Logger.new("vagrant::util::downloader")
        @source      = source.to_s
        @destination = destination.to_s

        begin
          url = URI.parse(@source)
          if url.scheme && url.scheme.start_with?("http") && url.user
            auth = "#{URI.unescape(url.user)}"
            auth += ":#{URI.unescape(url.password)}" if url.password
            url.user = nil
            url.password = nil
            options[:auth] ||= auth
            @source = url.to_s
          end
        rescue URI::InvalidURIError
        end

        @auth        = options[:auth]
        @ca_cert     = options[:ca_cert]
        @ca_path     = options[:ca_path]
        @continue    = options[:continue]
        @headers     = options[:headers]
        @insecure    = options[:insecure]
        @ui          = options[:ui]
        @client_cert = options[:client_cert]
        @location_trusted = options[:location_trusted]
      end

      def download!
        data_proc = nil

        extra_subprocess_opts = {}
        if @ui
          extra_subprocess_opts[:notify] = :stderr

          progress_data = ""
          progress_regexp = /(\r(.+?))\r/

          data_proc = Proc.new do |type, data|

            progress_data << data

            while true
              match = progress_regexp.match(progress_data)
              break if !match
              data = match[2]
              progress_data.gsub!(match[1], "")

              columns = data.strip.split(/\s+/)


              output = "Progress: #{columns[0]}% (Rate: #{columns[11]}/s, Estimated time remaining: #{columns[10]})"
              @ui.clear_line
              @ui.detail(output, new_line: false)
            end
          end
        end

        @logger.info("Downloader starting download: ")
        @logger.info("  -- Source: #{@source}")
        @logger.info("  -- Destination: #{@destination}")

        retried = false
        begin
          options, subprocess_options = self.options
          options += ["--output", @destination]
          options << @source

          subprocess_options.merge!(extra_subprocess_opts)

          execute_curl(options, subprocess_options, &data_proc)
        rescue Errors::DownloaderError => e
          raise if retried

          raise if e.extra_data[:exit_code].to_i != 33

          @continue = false
          retried = true
          retry
        ensure
          if @ui
            @ui.clear_line

            @ui.detail("") if Platform.windows?
          end
        end

        true
      end

      def head
        options, subprocess_options = self.options
        options.unshift("-I")
        options << @source

        @logger.info("HEAD: #{@source}")
        result = execute_curl(options, subprocess_options)
        result.stdout
      end

      protected

      def execute_curl(options, subprocess_options, &data_proc)
        options = options.dup
        options << subprocess_options

        interrupted  = false
        int_callback = Proc.new do
          @logger.info("Downloader interrupted!")
          interrupted = true
        end

        result = Busy.busy(int_callback) do
          Subprocess.execute("curl", *options, &data_proc)
        end

        raise Errors::DownloaderInterrupted if interrupted

        if result.exit_code != 0
          @logger.warn("Downloader exit code: #{result.exit_code}")
          parts    = result.stderr.split(/\n*curl:\s+\(\d+\)\s*/, 2)
          parts[1] ||= ""
          raise Errors::DownloaderError,
            code: result.exit_code,
            message: parts[1].chomp
        end

        result
      end

      def options
        options = [
          "-q",
          "--fail",
          "--location",
          "--max-redirs", "10",
          "--user-agent", USER_AGENT,
        ]

        options += ["--cacert", @ca_cert] if @ca_cert
        options += ["--capath", @ca_path] if @ca_path
        options += ["--continue-at", "-"] if @continue
        options << "--insecure" if @insecure
        options << "--cert" << @client_cert if @client_cert
        options << "-u" << @auth if @auth
        options << "--location-trusted" if @location_trusted

        if @headers
          Array(@headers).each do |header|
            options << "-H" << header
          end
        end

        subprocess_options = {}

        if Vagrant.in_installer?
          subprocess_options[:env] ||= {}
          subprocess_options[:env]["CURL_CA_BUNDLE"] =
            File.expand_path("cacert.pem", ENV["VAGRANT_INSTALLER_EMBEDDED_DIR"])
        end

        return [options, subprocess_options]
      end
    end
  end
end
