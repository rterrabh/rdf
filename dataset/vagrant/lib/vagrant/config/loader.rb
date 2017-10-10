require "pathname"

require "log4r"

module Vagrant
  module Config
    class Loader
      def initialize(versions, version_order)
        @logger        = Log4r::Logger.new("vagrant::config::loader")
        @config_cache  = {}
        @proc_cache    = {}
        @sources       = {}
        @versions      = versions
        @version_order = version_order
      end

      def set(name, sources)
        @logger.info("Set #{name.inspect} = #{sources.inspect}")

        sources = [sources] if !sources.kind_of?(Array)

        procs = []
        sources.each do |source|
          if !@proc_cache.key?(source)
            @logger.debug("Populating proc cache for #{source.inspect}")
            @proc_cache[source] = procs_for_source(source)
          end

          procs.concat(@proc_cache[source])
        end

        @sources[name] = procs
      end

      def load(order)
        @logger.info("Loading configuration in order: #{order.inspect}")

        unknown_sources = @sources.keys - order
        if !unknown_sources.empty?
          @logger.error("Unknown config sources: #{unknown_sources.inspect}")
        end

        current_version      = @version_order.last
        current_config_klass = @versions.get(current_version)

        result = current_config_klass.init

        warnings = []
        errors   = []

        order.each do |key|
          next if !@sources.key?(key)

          @sources[key].each do |version, proc|
            if !@config_cache.key?(proc)
              @logger.debug("Loading from: #{key} (evaluating)")

              version_loader = @versions.get(version)
              version_config = version_loader.load(proc)

              version_warnings = []
              version_errors   = []

              if version != current_version
                @logger.debug("Upgrading config from version #{version} to #{current_version}")
                version_index = @version_order.index(version)
                current_index = @version_order.index(current_version)

                (version_index + 1).upto(current_index) do |index|
                  next_version = @version_order[index]
                  @logger.debug("Upgrading config to version #{next_version}")

                  loader = @versions.get(next_version)
                  upgrade_result = loader.upgrade(version_config)

                  this_warnings = upgrade_result[1]
                  this_errors   = upgrade_result[2]
                  @logger.debug("Upgraded to version #{next_version} with " +
                                "#{this_warnings.length} warnings and " +
                                "#{this_errors.length} errors")

                  version_warnings += this_warnings
                  version_errors   += this_errors

                  version_config = upgrade_result[0]
                end
              end

              @config_cache[proc] = [version_config, version_warnings, version_errors]
            else
              @logger.debug("Loading from: #{key} (cache)")
            end

            cache_data = @config_cache[proc]
            result = current_config_klass.merge(result, cache_data[0])

            warnings += cache_data[1]
            errors   += cache_data[2]
          end
        end

        @logger.debug("Configuration loaded successfully, finalizing and returning")
        [current_config_klass.finalize(result), warnings, errors]
      end

      protected

      def procs_for_source(source)
        source = source.to_s if source.is_a?(Pathname)

        if source.is_a?(Array)
          raise ArgumentError, "String source must have format [version, proc]" if source.length != 2

          return [source]
        elsif source.is_a?(String)
          return procs_for_path(source)
        else
          raise ArgumentError, "Unknown configuration source: #{source.inspect}"
        end
      end

      def procs_for_path(path)
        @logger.debug("Load procs for pathname: #{path}")

        return Config.capture_configures do
          begin
            Kernel.load path
          rescue SyntaxError => e
            raise Errors::VagrantfileSyntaxError, file: e.message
          rescue SystemExit
            raise
          rescue Vagrant::Errors::VagrantError
            raise
          rescue Exception => e
            @logger.error("Vagrantfile load error: #{e.message}")
            @logger.error(e.backtrace.join("\n"))

            line = "(unknown)"
            if e.backtrace && e.backtrace[0]
              line = e.backtrace[0].split(":")[1]
            end

            raise Errors::VagrantfileLoadError,
              path: path,
              line: line,
              exception_class: e.class,
              message: e.message
          end
        end
      end
    end
  end
end
