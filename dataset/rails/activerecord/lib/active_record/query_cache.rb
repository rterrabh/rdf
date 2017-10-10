module ActiveRecord
  class QueryCache
    module ClassMethods
      def cache(&block)
        if ActiveRecord::Base.connected?
          connection.cache(&block)
        else
          yield
        end
      end

      def uncached(&block)
        if ActiveRecord::Base.connected?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      connection    = ActiveRecord::Base.connection
      enabled       = connection.query_cache_enabled
      connection_id = ActiveRecord::Base.connection_id
      connection.enable_query_cache!

      response = @app.call(env)
      response[2] = Rack::BodyProxy.new(response[2]) do
        restore_query_cache_settings(connection_id, enabled)
      end

      response
    rescue Exception => e
      restore_query_cache_settings(connection_id, enabled)
      raise e
    end

    private

    def restore_query_cache_settings(connection_id, enabled)
      ActiveRecord::Base.connection_id = connection_id
      ActiveRecord::Base.connection.clear_query_cache
      ActiveRecord::Base.connection.disable_query_cache! unless enabled
    end

  end
end
