module Trashable
  extend ActiveSupport::Concern

  included do
    default_scope { where(with_deleted_scope_sql) }

    belongs_to :deleted_by, class_name: 'User'
  end


  module ClassMethods
    def with_deleted
      scope = self.all

      scope.where_values.delete(with_deleted_scope_sql)
      scope
    end

    def with_deleted_scope_sql
      all.table[:deleted_at].eq(nil).to_sql
    end
  end

  def trashed?
    deleted_at.present?
  end

  def trash!(trashed_by=nil)
    trash_update(DateTime.now, trashed_by.try(:id))
  end

  def recover!
    trash_update(nil, nil)
  end


  private

    def trash_update(deleted_at, deleted_by_id)
      self.class.unscoped.where(id: self.id).update_all(deleted_at: deleted_at, deleted_by_id: deleted_by_id)
      raw_write_attribute :deleted_at, deleted_at
      raw_write_attribute :deleted_by_id, deleted_by_id
    end

end
