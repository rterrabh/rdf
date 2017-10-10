
class ProjectSnippet < Snippet
  belongs_to :project
  belongs_to :author, class_name: "User"

  validates :project, presence: true

  scope :fresh, -> { order("created_at DESC") }
  scope :non_expired, -> { where(["expires_at IS NULL OR expires_at > ?", Time.current]) }
  scope :expired, -> { where(["expires_at IS NOT NULL AND expires_at < ?", Time.current]) }
end
