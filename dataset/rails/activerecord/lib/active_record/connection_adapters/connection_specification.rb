require 'uri'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method

      def initialize(config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end

      def initialize_dup(original)
        @config = original.config.dup
      end

      class ConnectionUrlResolver # :nodoc:

        def initialize(url)
          raise "Database URL cannot be empty" if url.blank?
          @uri     = uri_parser.parse(url)
          @adapter = @uri.scheme.tr('-', '_')
          @adapter = "postgresql" if @adapter == "postgres"

          if @uri.opaque
            @uri.opaque, @query = @uri.opaque.split('?', 2)
          else
            @query = @uri.query
          end
        end

        def to_hash
          config = raw_config.reject { |_,value| value.blank? }
          config.map { |key,value| config[key] = uri_parser.unescape(value) if value.is_a? String }
          config
        end

        private

        def uri
          @uri
        end

        def uri_parser
          @uri_parser ||= URI::Parser.new
        end

        def query_hash
          Hash[(@query || '').split("&").map { |pair| pair.split("=") }]
        end

        def raw_config
          if uri.opaque
            query_hash.merge({
              "adapter"  => @adapter,
              "database" => uri.opaque })
          else
            query_hash.merge({
              "adapter"  => @adapter,
              "username" => uri.user,
              "password" => uri.password,
              "port"     => uri.port,
              "database" => database_from_path,
              "host"     => uri.hostname })
          end
        end

        def database_from_path
          if @adapter == 'sqlite3'

            uri.path
          else

            uri.path.sub(%r{^/}, "")
          end
        end
      end

      class Resolver # :nodoc:
        attr_reader :configurations

        def initialize(configurations)
          @configurations = configurations
        end

        def resolve(config)
          if config
            resolve_connection config
          elsif env = ActiveRecord::ConnectionHandling::RAILS_ENV.call
            resolve_symbol_connection env.to_sym
          else
            raise AdapterNotSpecified
          end
        end

        def resolve_all
          config = configurations.dup
          config.each do |key, value|
            config[key] = resolve(value) if value
          end
          config
        end

        def spec(config)
          spec = resolve(config).symbolize_keys

          raise(AdapterNotSpecified, "database configuration does not specify adapter") unless spec.key?(:adapter)

          path_to_adapter = "active_record/connection_adapters/#{spec[:adapter]}_adapter"
          begin
            require path_to_adapter
          rescue Gem::LoadError => e
            raise Gem::LoadError, "Specified '#{spec[:adapter]}' for database adapter, but the gem is not loaded. Add `gem '#{e.name}'` to your Gemfile (and ensure its version is at the minimum required by ActiveRecord)."
          rescue LoadError => e
            raise LoadError, "Could not load '#{path_to_adapter}'. Make sure that the adapter in config/database.yml is valid. If you use an adapter other than 'mysql', 'mysql2', 'postgresql' or 'sqlite3' add the necessary adapter gem to the Gemfile.", e.backtrace
          end

          adapter_method = "#{spec[:adapter]}_connection"
          ConnectionSpecification.new(spec, adapter_method)
        end

        private

        def resolve_connection(spec)
          case spec
          when Symbol
            resolve_symbol_connection spec
          when String
            resolve_string_connection spec
          when Hash
            resolve_hash_connection spec
          end
        end

        def resolve_string_connection(spec)
          if configurations.key?(spec) || spec !~ /:/
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing a string to ActiveRecord::Base.establish_connection for a
              configuration lookup is deprecated, please pass a symbol
              (#{spec.to_sym.inspect}) instead.
            MSG

            resolve_symbol_connection(spec)
          else
            resolve_url_connection(spec)
          end
        end

        def resolve_symbol_connection(spec)
          if config = configurations[spec.to_s]
            resolve_connection(config)
          else
            raise(AdapterNotSpecified, "'#{spec}' database is not configured. Available: #{configurations.keys.inspect}")
          end
        end

        def resolve_hash_connection(spec)
          if spec["url"] && spec["url"] !~ /^jdbc:/
            connection_hash = resolve_url_connection(spec.delete("url"))
            spec.merge!(connection_hash)
          end
          spec
        end

        def resolve_url_connection(url)
          ConnectionUrlResolver.new(url).to_hash
        end
      end
    end
  end
end
