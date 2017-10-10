require 'fileutils'
require "tempfile"

require "json"
require "log4r"

require "vagrant/box_metadata"
require "vagrant/util/downloader"
require "vagrant/util/platform"
require "vagrant/util/safe_chdir"
require "vagrant/util/subprocess"

module Vagrant
  class Box
    include Comparable

    attr_reader :name

    attr_reader :provider

    attr_reader :version

    attr_reader :directory

    attr_reader :metadata

    attr_reader :metadata_url

    def initialize(name, provider, version, directory, **opts)
      @name      = name
      @version   = version
      @provider  = provider
      @directory = directory
      @metadata_url = opts[:metadata_url]

      metadata_file = directory.join("metadata.json")
      raise Errors::BoxMetadataFileNotFound, name: @name if !metadata_file.file?

      begin
        @metadata = JSON.parse(directory.join("metadata.json").read)
      rescue JSON::ParserError
        raise Errors::BoxMetadataCorrupted, name: @name
      end

      @logger = Log4r::Logger.new("vagrant::box")
    end

    def destroy!
      FileUtils.rm_r(@directory)

      true
    rescue Errno::ENOENT
      return true
    end

    def in_use?(index)
      results = []
      index.each do |entry|
        box_data = entry.extra_data["box"]
        next if !box_data

        if box_data["name"] == self.name &&
          box_data["provider"] == self.provider.to_s &&
          box_data["version"] == self.version.to_s
          results << entry
        end
      end

      return nil if results.empty?
      results
    end

    def load_metadata
      tf = Tempfile.new("vagrant")
      tf.close

      url = @metadata_url
      if File.file?(url) || url !~ /^[a-z0-9]+:.*$/i
        url = File.expand_path(url)
        url = Util::Platform.cygwin_windows_path(url)
        url = "file:#{url}"
      end

      opts = { headers: ["Accept: application/json"] }
      Util::Downloader.new(url, tf.path, **opts).download!
      BoxMetadata.new(File.open(tf.path, "r"))
    rescue Errors::DownloaderError => e
      raise Errors::BoxMetadataDownloadError,
        message: e.extra_data[:message]
    ensure
      tf.unlink if tf
    end

    def has_update?(version=nil)
      if !@metadata_url
        raise Errors::BoxUpdateNoMetadata, name: @name
      end

      version += ", " if version
      version ||= ""
      version += "> #{@version}"
      md      = self.load_metadata
      newer   = md.version(version, provider: @provider)
      return nil if !newer

      [md, newer, newer.provider(@provider)]
    end

    def repackage(path)
      @logger.debug("Repackaging box '#{@name}' to: #{path}")

      Util::SafeChdir.safe_chdir(@directory) do
        files = Dir.glob(File.join(".", "**", "*")).select { |f| File.file?(f) }

        Util::Subprocess.execute("bsdtar", "-czf", path.to_s, *files)
      end

      @logger.info("Repackaged box '#{@name}' successfully: #{path}")

      true
    end

    def <=>(other)
      return super if !other.is_a?(self.class)

      "#{@name}-#{@version}-#{@provider}" <=>
      "#{other.name}-#{other.version}-#{other.provider}"
    end
  end
end
