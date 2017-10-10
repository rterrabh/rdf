module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module QueryCache
      class << self
        def included(base) #:nodoc:
          dirties_query_cache base, :insert, :update, :delete, :rollback_to_savepoint, :rollback_db_transaction
        end

        def dirties_query_cache(base, *method_names)
          method_names.each do |method_name|
            #nodyna <class_eval-913> <not yet classified>
            base.class_eval <<-end_code, __FILE__, __LINE__ + 1
              def #{method_name}(*)
                clear_query_cache if @query_cache_enabled
                super
              end
            end_code
          end
        end
      end

      attr_reader :query_cache, :query_cache_enabled

      def initialize(*)
        super
        @query_cache         = Hash.new { |h,sql| h[sql] = {} }
        @query_cache_enabled = false
      end

      def cache
        old, @query_cache_enabled = @query_cache_enabled, true
        yield
      ensure
        @query_cache_enabled = old
        clear_query_cache unless @query_cache_enabled
      end

      def enable_query_cache!
        @query_cache_enabled = true
      end

      def disable_query_cache!
        @query_cache_enabled = false
      end

      def uncached
        old, @query_cache_enabled = @query_cache_enabled, false
        yield
      ensure
        @query_cache_enabled = old
      end

      def clear_query_cache
        @query_cache.clear
      end

      def select_all(arel, name = nil, binds = [])
        if @query_cache_enabled && !locked?(arel)
          arel, binds = binds_from_relation arel, binds
          sql = to_sql(arel, binds)
          cache_sql(sql, binds) { super(sql, name, binds) }
        else
          super
        end
      end

      private

      def cache_sql(sql, binds)
        result =
          if @query_cache[sql].key?(binds)
            ActiveSupport::Notifications.instrument("sql.active_record",
              :sql => sql, :binds => binds, :name => "CACHE", :connection_id => object_id)
            @query_cache[sql][binds]
          else
            @query_cache[sql][binds] = yield
          end
        result.dup
      end

      def locked?(arel)
        arel.respond_to?(:locked) && arel.locked
      end
    end
  end
end
