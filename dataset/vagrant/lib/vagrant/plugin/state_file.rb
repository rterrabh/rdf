require "json"

module Vagrant
  module Plugin
    class StateFile
      def initialize(path)
        @path = path

        @data = {}
        if @path.exist?
          begin
            @data = JSON.parse(@path.read)
          rescue JSON::ParserError => e
            raise Vagrant::Errors::PluginStateFileParseError,
              path: path, message: e.message
          end

          upgrade_v0! if !@data["version"]
        end

        @data["version"] ||= "1"
        @data["installed"] ||= {}
      end

      def add_plugin(name, **opts)
        @data["installed"][name] = {
          "ruby_version"    => RUBY_VERSION,
          "vagrant_version" => Vagrant::VERSION,
          "gem_version"     => opts[:version] || "",
          "require"         => opts[:require] || "",
          "sources"         => opts[:sources] || [],
        }

        save!
      end

      def add_source(url)
        @data["sources"] ||= []
        @data["sources"] << url if !@data["sources"].include?(url)
        save!
      end

      def installed_plugins
        @data["installed"]
      end

      def has_plugin?(name)
        @data["installed"].key?(name)
      end

      def remove_plugin(name)
        @data["installed"].delete(name)
        save!
      end

      def remove_source(url)
        @data["sources"] ||= []
        @data["sources"].delete(url)
        save!
      end

      def sources
        @data["sources"] || []
      end

      def save!
        @path.open("w+") do |f|
          f.write(JSON.dump(@data))
        end
      end

      protected

      def upgrade_v0!
        @data["version"] = "1"

        new_installed = {}
        (@data["installed"] || []).each do |plugin|
          new_installed[plugin] = {
            "ruby_version"    => "0",
            "vagrant_version" => "0",
          }
        end

        @data["installed"] = new_installed

        save!
      end
    end
  end
end
