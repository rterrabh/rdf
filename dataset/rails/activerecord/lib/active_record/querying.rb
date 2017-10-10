module ActiveRecord
  module Querying
    delegate :find, :take, :take!, :first, :first!, :last, :last!, :exists?, :any?, :many?, to: :all
    delegate :second, :second!, :third, :third!, :fourth, :fourth!, :fifth, :fifth!, :forty_two, :forty_two!, to: :all
    delegate :first_or_create, :first_or_create!, :first_or_initialize, to: :all
    delegate :find_or_create_by, :find_or_create_by!, :find_or_initialize_by, to: :all
    delegate :find_by, :find_by!, to: :all
    delegate :destroy, :destroy_all, :delete, :delete_all, :update, :update_all, to: :all
    delegate :find_each, :find_in_batches, to: :all
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins,
             :where, :rewhere, :preload, :eager_load, :includes, :from, :lock, :readonly,
             :having, :create_with, :uniq, :distinct, :references, :none, :unscope, to: :all
    delegate :count, :average, :minimum, :maximum, :sum, :calculate, to: :all
    delegate :pluck, :ids, to: :all

    def find_by_sql(sql, binds = [])
      result_set = connection.select_all(sanitize_sql(sql), "#{name} Load", binds)
      column_types = result_set.column_types.dup
      columns_hash.each_key { |k| column_types.delete k }
      message_bus = ActiveSupport::Notifications.instrumenter

      payload = {
        record_count: result_set.length,
        class_name: name
      }

      message_bus.instrument('instantiation.active_record', payload) do
        result_set.map { |record| instantiate(record, column_types) }
      end
    end

    def count_by_sql(sql)
      sql = sanitize_conditions(sql)
      connection.select_value(sql, "#{name} Count").to_i
    end
  end
end
