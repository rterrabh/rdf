
class ProjectHook < WebHook
  belongs_to :project

  scope :push_hooks, -> { where(push_events: true) }
  scope :tag_push_hooks, -> { where(tag_push_events: true) }
  scope :issue_hooks, -> { where(issues_events: true) }
  scope :note_hooks, -> { where(note_events: true) }
  scope :merge_request_hooks, -> { where(merge_requests_events: true) }
end
