
require 'carrierwave/orm/activerecord'
require 'file_size_validator'

class Issue < ActiveRecord::Base
  include InternalId
  include Issuable
  include Referable
  include Sortable
  include Taskable

  ActsAsTaggableOn.strict_case_match = true

  belongs_to :project
  validates :project, presence: true

  scope :of_group, ->(group) { where(project_id: group.project_ids) }
  scope :cared, ->(user) { where(assignee_id: user) }
  scope :open_for, ->(user) { opened.assigned_to(user) }

  state_machine :state, initial: :opened do
    event :close do
      transition [:reopened, :opened] => :closed
    end

    event :reopen do
      transition closed: :reopened
    end

    state :opened
    state :reopened
    state :closed
  end

  def hook_attrs
    attributes
  end

  def self.reference_prefix
    '#'
  end

  def self.reference_pattern
    %r{
      (#{Project.reference_pattern})?
    }x
  end

  def to_reference(from_project = nil)
    reference = "#{self.class.reference_prefix}#{iid}"

    if cross_project_reference?(from_project)
      reference = project.to_reference + reference
    end

    reference
  end

  def reset_events_cache
    Event.reset_event_cache_for(self)
  end

  def source_project
    project
  end
end
