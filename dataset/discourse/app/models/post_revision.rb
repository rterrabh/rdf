require_dependency "discourse_diff"

class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash

  def self.ensure_consistency!
    PostRevision.exec_sql <<-SQL
      UPDATE post_revisions
         SET number = pr.rank
        FROM (SELECT id, 1 + ROW_NUMBER() OVER (PARTITION BY post_id ORDER BY number, created_at, updated_at) AS rank FROM post_revisions) AS pr
       WHERE post_revisions.id = pr.id
         AND post_revisions.number <> pr.rank
    SQL

    PostRevision.exec_sql <<-SQL
      UPDATE posts
         SET version = 1 + (SELECT COUNT(*) FROM post_revisions WHERE post_id = posts.id),
             public_version = 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
       WHERE version <> 1 + (SELECT COUNT(*) FROM post_revisions WHERE post_id = posts.id)
          OR public_version <> 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
    SQL
  end

  def hide!
    update_column(:hidden, true)
  end

  def show!
    update_column(:hidden, false)
  end

end

