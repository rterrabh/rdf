require "monitor"
require "pathname"
require "set"
require "tempfile"

require "bundler"

require_relative "shared_helpers"
require_relative "version"

module Vagrant
  class Bundler
    def self.instance
      @bundler ||= self.new
    end

    def initialize
      @enabled = true if ENV["VAGRANT_INSTALLER_ENV"] ||
        ENV["VAGRANT_FORCE_BUNDLER"]
      @enabled  = !::Bundler::SharedHelpers.in_bundle? if !@enabled
      @monitor  = Monitor.new

      @gem_home = ENV["GEM_HOME"]
      @gem_path = ENV["GEM_PATH"]

      ::Bundler.ui =
        if ::Bundler::UI.const_defined? :Silent
          BundlerUI.new
        else
          ::Bundler::UI.new
        end
      if !::Bundler.ui.respond_to?(:silence)
        ui = ::Bundler.ui
        def ui.silence(*args)
          yield
        end
      end
    end

    def init!(plugins)
      return if !@enabled

      bundle_path = Vagrant.user_data_path.join("gems")

      @appconfigpath = Dir.mktmpdir
      File.open(File.join(@appconfigpath, "config"), "w+") do |f|
        f.write("BUNDLE_PATH: \"#{bundle_path}\"")
      end

      @configfile = File.open(Tempfile.new("vagrant").path + "1", "w+")
      @configfile.close

      @gemfile = build_gemfile(plugins)

      ENV["BUNDLE_APP_CONFIG"] = @appconfigpath
      ENV["BUNDLE_CONFIG"]  = @configfile.path
      ENV["BUNDLE_GEMFILE"] = @gemfile.path
      ENV["GEM_PATH"] =
        "#{bundle_path}#{::File::PATH_SEPARATOR}#{@gem_path}"
      Gem.clear_paths
    end

    def deinit
      File.unlink(ENV["BUNDLE_APP_CONFIG"]) rescue nil
      File.unlink(ENV["BUNDLE_CONFIG"]) rescue nil
      File.unlink(ENV["GEMFILE"]) rescue nil
    end

    def install(plugins, local=false)
      internal_install(plugins, nil, local: local)
    end

    def install_local(path)
      require "rubygems/dependency_installer"
      begin
        require "rubygems/format"
      rescue LoadError
      end

      pkg = if defined?(Gem::Format)
              Gem::Format.from_file_by_path(path)
            else
              Gem::Package.new(path)
            end

      with_isolated_gem do
        installer = Gem::DependencyInstaller.new(
          document: [], prerelease: false)
        installer.install(path, "= #{pkg.spec.version}")
      end

      pkg.spec
    end

    def update(plugins, specific)
      specific ||= []
      update = true
      update = { gems: specific } if !specific.empty?
      internal_install(plugins, update)
    end

    def clean(plugins)
      gemfile    = build_gemfile(plugins)
      lockfile   = "#{gemfile.path}.lock"
      definition = ::Bundler::Definition.build(gemfile, lockfile, nil)
      root       = File.dirname(gemfile.path)

      with_isolated_gem do
        runtime = ::Bundler::Runtime.new(root, definition)
        runtime.clean
      end
    end

    def verbose
      @monitor.synchronize do
        begin
          old_ui = ::Bundler.ui
          require 'bundler/vendored_thor'
          ::Bundler.ui = ::Bundler::UI::Shell.new
          yield
        ensure
          ::Bundler.ui = old_ui
        end
      end
    end

    protected

    def build_gemfile(plugins)
      sources = plugins.values.map { |p| p["sources"] }.flatten.compact.uniq

      f = File.open(Tempfile.new("vagrant").path + "2", "w+")
      f.tap do |gemfile|
        if !sources.include?("http://rubygems.org")
          gemfile.puts(%Q[source "https://rubygems.org"])
        end

        gemfile.puts(%Q[source "http://gems.hashicorp.com"])
        sources.each do |source|
          next if source == ""
          gemfile.puts(%Q[source "#{source}"])
        end

        gemfile.puts(%Q[gem "vagrant", "= #{VERSION}"])

        gemfile.puts("group :plugins do")
        plugins.each do |name, plugin|
          version = plugin["gem_version"]
          version = nil if version == ""

          opts = {}
          if plugin["require"] && plugin["require"] != ""
            opts[:require] = plugin["require"]
          end

          gemfile.puts(%Q[gem "#{name}", #{version.inspect}, #{opts.inspect}])
        end
        gemfile.puts("end")

        gemfile.close
      end
    end

    def internal_install(plugins, update, **extra)
      gemfile    = build_gemfile(plugins)
      lockfile   = "#{gemfile.path}.lock"
      definition = ::Bundler::Definition.build(gemfile, lockfile, update)
      root       = File.dirname(gemfile.path)
      opts       = {}
      opts["local"] = true if extra[:local]

      with_isolated_gem do
        ::Bundler::Installer.install(root, definition, opts)
      end


      definition.specs
    rescue ::Bundler::VersionConflict => e
      raise Errors::PluginInstallVersionConflict,
        conflicts: e.to_s.gsub("Bundler", "Vagrant")
    rescue ::Bundler::BundlerError => e
      if !::Bundler.ui.is_a?(BundlerUI)
        raise
      end

      message = "#{e.message}"
      if ::Bundler.ui.output != ""
        message += "\n\n#{::Bundler.ui.output}"
      end

      raise ::Bundler::BundlerError, message
    end

    def with_isolated_gem
      raise Errors::BundlerDisabled if !@enabled

      old_rubyopt = ENV["RUBYOPT"]
      old_gemfile = ENV["BUNDLE_GEMFILE"]
      ENV["BUNDLE_GEMFILE"] = Tempfile.new("vagrant-gemfile").path
      ENV["RUBYOPT"] = (ENV["RUBYOPT"] || "").gsub(/-rbundler\/setup\s*/, "")

      ENV["GEM_HOME"] = Vagrant.user_data_path.join("gems").to_s

      Gem.paths = ENV

      old_all = Gem::Specification._all
      Gem::Specification.all = nil

      old_config = nil
      begin
        old_config = Gem.configuration
      rescue Psych::SyntaxError
      end
      Gem.configuration = NilGemConfig.new

      Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
        return yield
      end
    ensure
      ENV["BUNDLE_GEMFILE"] = old_gemfile
      ENV["GEM_HOME"] = @gem_home
      ENV["RUBYOPT"]  = old_rubyopt

      Gem.configuration = old_config
      Gem.paths = ENV
      Gem::Specification.all = old_all
    end

    class NilGemConfig < Gem::ConfigFile
      def initialize

        @api_keys       = {}
        @args           = []
        @backtrace      = false
        @bulk_threshold = 1000
        @hash           = {}
        @update_sources = true
        @verbose        = true
      end
    end

    if ::Bundler::UI.const_defined? :Silent
      class BundlerUI < ::Bundler::UI::Silent
        attr_reader :output

        def initialize
          @output = ""
        end

        def info(message, newline = nil)
        end

        def confirm(message, newline = nil)
        end

        def warn(message, newline = nil)
          @output += message
          @output += "\n" if newline
        end

        def error(message, newline = nil)
          @output += message
          @output += "\n" if newline
        end

        def debug(message, newline = nil)
        end

        def debug?
          false
        end

        def quiet?
          false
        end

        def ask(message)
        end

        def level=(name)
        end

        def level(name = nil)
          "info"
        end

        def trace(message, newline = nil)
        end

        def silence
          yield
        end
      end
    end
  end
end
