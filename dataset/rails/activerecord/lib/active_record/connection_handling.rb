module ActiveRecord
  module ConnectionHandling
    RAILS_ENV   = -> { (Rails.env if defined?(Rails.env)) || ENV["RAILS_ENV"] || ENV["RACK_ENV"] }
    DEFAULT_ENV = -> { RAILS_ENV.call || "default_env" }

    def establish_connection(spec = nil)
      spec     ||= DEFAULT_ENV.call.to_sym
      resolver =   ConnectionAdapters::ConnectionSpecification::Resolver.new configurations
      spec     =   resolver.spec(spec)

      unless respond_to?(spec.adapter_method)
        raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
      end

      remove_connection
      connection_handler.establish_connection self, spec
    end

    class MergeAndResolveDefaultUrlConfig # :nodoc:
      def initialize(raw_configurations)
        @raw_config = raw_configurations.dup
        @env = DEFAULT_ENV.call.to_s
      end

      def resolve
        ConnectionAdapters::ConnectionSpecification::Resolver.new(config).resolve_all
      end

      private
        def config
          @raw_config.dup.tap do |cfg|
            if url = ENV['DATABASE_URL']
              cfg[@env] ||= {}
              cfg[@env]["url"] ||= url
            end
          end
        end
    end

    def connection
      retrieve_connection
    end

    def connection_id
      ActiveRecord::RuntimeRegistry.connection_id
    end

    def connection_id=(connection_id)
      ActiveRecord::RuntimeRegistry.connection_id = connection_id
    end

    def connection_config
      connection_pool.spec.config
    end

    def connection_pool
      connection_handler.retrieve_connection_pool(self) or raise ConnectionNotEstablished
    end

    def retrieve_connection
      connection_handler.retrieve_connection(self)
    end

    def connected?
      connection_handler.connected?(self)
    end

    def remove_connection(klass = self)
      connection_handler.remove_connection(klass)
    end

    def clear_cache! # :nodoc:
      connection.schema_cache.clear!
    end

    delegate :clear_active_connections!, :clear_reloadable_connections!,
      :clear_all_connections!, :to => :connection_handler
  end
end
