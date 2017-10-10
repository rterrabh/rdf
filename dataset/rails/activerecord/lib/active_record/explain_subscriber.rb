require 'active_support/notifications'
require 'active_record/explain_registry'

module ActiveRecord
  class ExplainSubscriber # :nodoc:
    def start(name, id, payload)
    end

    def finish(name, id, payload)
      if ExplainRegistry.collect? && !ignore_payload?(payload)
        ExplainRegistry.queries << payload.values_at(:sql, :binds)
      end
    end

    IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN CACHE)
    EXPLAINED_SQLS = /\A\s*(with|select|update|delete|insert)\b/i
    def ignore_payload?(payload)
      payload[:exception] || IGNORED_PAYLOADS.include?(payload[:name]) || payload[:sql] !~ EXPLAINED_SQLS
    end

    ActiveSupport::Notifications.subscribe("sql.active_record", new)
  end
end
