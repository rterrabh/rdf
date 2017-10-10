require "json"

module Vagrant
  class BoxMetadata
    attr_accessor :name

    attr_accessor :description

    def initialize(io)
      begin
        @raw = JSON.load(io)
      rescue JSON::ParserError => e
        raise Errors::BoxMetadataMalformed,
          error: e.to_s
      end

      @raw ||= {}
      @name = @raw["name"]
      @description = @raw["description"]
      @version_map = (@raw["versions"] || []).map do |v|
        begin
          [Gem::Version.new(v["version"]), v]
        rescue ArgumentError
          raise Errors::BoxMetadataMalformedVersion,
            version: v["version"].to_s
        end
      end
      @version_map = Hash[@version_map]
    end

    def version(version, **opts)
      requirements = version.split(",").map do |v|
        Gem::Requirement.new(v.strip)
      end

      providers = nil
      providers = Array(opts[:provider]).map(&:to_sym) if opts[:provider]

      @version_map.keys.sort.reverse.each do |v|
        next if !requirements.all? { |r| r.satisfied_by?(v) }
        version = Version.new(@version_map[v])
        next if (providers & version.providers).empty? if providers
        return version
      end

      nil
    end

    def versions
      @version_map.keys.sort.map(&:to_s)
    end

    class Version
      attr_accessor :version

      def initialize(raw=nil)
        return if !raw

        @version = raw["version"]
        @provider_map = (raw["providers"] || []).map do |p|
          [p["name"].to_sym, p]
        end
        @provider_map = Hash[@provider_map]
      end

      def provider(name)
        p = @provider_map[name.to_sym]
        return nil if !p
        Provider.new(p)
      end

      def providers
        @provider_map.keys.map(&:to_sym)
      end
    end

    class Provider
      attr_accessor :name

      attr_accessor :url

      attr_accessor :checksum

      attr_accessor :checksum_type

      def initialize(raw)
        @name = raw["name"]
        @url  = raw["url"]
        @checksum = raw["checksum"]
        @checksum_type = raw["checksum_type"]
      end
    end
  end
end
