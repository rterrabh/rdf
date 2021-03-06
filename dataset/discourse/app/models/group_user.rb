class GroupUser < ActiveRecord::Base
  belongs_to :group, counter_cache: "user_count"
  belongs_to :user

  after_save :update_title
  after_destroy :remove_title

  after_save :set_primary_group
  after_destroy :remove_primary_group

  protected

  def set_primary_group
    if group.primary_group
        self.class.exec_sql("UPDATE users
                             SET primary_group_id = :id
                             WHERE id = :user_id",
                          id: group.id, user_id: user_id)
    end
  end

  def remove_primary_group
      self.class.exec_sql("UPDATE users
                           SET primary_group_id = NULL
                           WHERE id = :user_id AND primary_group_id = :id",
                        id: group.id, user_id: user_id)

  end

  def remove_title
    if group.title.present?
        self.class.exec_sql("UPDATE users SET title = NULL
                          WHERE title = :title AND id = :id",
                          id: user_id,
                          title: group.title)
    end
  end

  def update_title
    if group.title.present?
      self.class.exec_sql("UPDATE users SET title = :title
                          WHERE (title IS NULL OR title = '') AND id = :id",
                          id: user_id,
                          title: group.title)
    end
  end
end

