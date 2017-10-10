
require Rails.root.join("app/models/commit")
require Rails.root.join("lib/static_model")

class MergeRequest < ActiveRecord::Base
  include InternalId
  include Issuable
  include Referable
  include Sortable
  include Taskable

  belongs_to :target_project, foreign_key: :target_project_id, class_name: "Project"
  belongs_to :source_project, foreign_key: :source_project_id, class_name: "Project"

  has_one :merge_request_diff, dependent: :destroy

  after_create :create_merge_request_diff
  after_update :update_merge_request_diff

  delegate :commits, :diffs, :last_commit, :last_commit_short_sha, to: :merge_request_diff, prefix: nil

  attr_accessor :should_remove_source_branch

  attr_accessor :allow_broken

  attr_accessor :can_be_created, :compare_failed,
    :compare_commits, :compare_diffs

  state_machine :state, initial: :opened do
    event :close do
      transition [:reopened, :opened] => :closed
    end

    event :merge do
      transition [:reopened, :opened, :locked] => :merged
    end

    event :reopen do
      transition closed: :reopened
    end

    event :lock_mr do
      transition [:reopened, :opened] => :locked
    end

    event :unlock_mr do
      transition locked: :reopened
    end

    after_transition any => :locked do |merge_request, transition|
      merge_request.locked_at = Time.now
      merge_request.save
    end

    after_transition locked: (any - :locked) do |merge_request, transition|
      merge_request.locked_at = nil
      merge_request.save
    end

    state :opened
    state :reopened
    state :closed
    state :merged
    state :locked
  end

  state_machine :merge_status, initial: :unchecked do
    event :mark_as_unchecked do
      transition [:can_be_merged, :cannot_be_merged] => :unchecked
    end

    event :mark_as_mergeable do
      transition [:unchecked, :cannot_be_merged] => :can_be_merged
    end

    event :mark_as_unmergeable do
      transition [:unchecked, :can_be_merged] => :cannot_be_merged
    end

    state :unchecked
    state :can_be_merged
    state :cannot_be_merged

    around_transition do |merge_request, transition, block|
      merge_request.record_timestamps = false
      begin
        block.call
      ensure
        merge_request.record_timestamps = true
      end
    end
  end

  validates :source_project, presence: true, unless: :allow_broken
  validates :source_branch, presence: true
  validates :target_project, presence: true
  validates :target_branch, presence: true
  validate :validate_branches
  validate :validate_fork

  scope :of_group, ->(group) { where("source_project_id in (:group_project_ids) OR target_project_id in (:group_project_ids)", group_project_ids: group.project_ids) }
  scope :by_branch, ->(branch_name) { where("(source_branch LIKE :branch) OR (target_branch LIKE :branch)", branch: branch_name) }
  scope :cared, ->(user) { where('assignee_id = :user OR author_id = :user', user: user.id) }
  scope :by_milestone, ->(milestone) { where(milestone_id: milestone) }
  scope :in_projects, ->(project_ids) { where("source_project_id in (:project_ids) OR target_project_id in (:project_ids)", project_ids: project_ids) }
  scope :of_projects, ->(ids) { where(target_project_id: ids) }
  scope :merged, -> { with_state(:merged) }
  scope :closed, -> { with_state(:closed) }
  scope :closed_and_merged, -> { with_states(:closed, :merged) }

  def self.reference_prefix
    '!'
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

  def validate_branches
    if target_project == source_project && target_branch == source_branch
      errors.add :branch_conflict, "You can not use same project/branch for source and target"
    end

    if opened? || reopened?
      similar_mrs = self.target_project.merge_requests.where(source_branch: source_branch, target_branch: target_branch, source_project_id: source_project.id).opened
      similar_mrs = similar_mrs.where('id not in (?)', self.id) if self.id
      if similar_mrs.any?
        errors.add :validate_branches,
                   "Cannot Create: This merge request already exists: #{
                   similar_mrs.pluck(:title)
                   }"
      end
    end
  end

  def validate_fork
    return true unless target_project && source_project

    if target_project == source_project
      true
    else
      if source_project.forked_from?(target_project)
        true
      else
        errors.add :validate_fork,
                   'Source project is not a fork of target project'
      end
    end
  end

  def update_merge_request_diff
    if source_branch_changed? || target_branch_changed?
      reload_code
    end
  end

  def reload_code
    if merge_request_diff && open?
      merge_request_diff.reload_content
    end
  end

  def check_if_can_be_merged
    if Gitlab::Satellite::MergeAction.new(self.author, self).can_be_merged?
      mark_as_mergeable
    else
      mark_as_unmergeable
    end
  end

  def merge_event
    self.target_project.events.where(target_id: self.id, target_type: "MergeRequest", action: Event::MERGED).last
  end

  def closed_event
    self.target_project.events.where(target_id: self.id, target_type: "MergeRequest", action: Event::CLOSED).last
  end

  def automerge!(current_user, commit_message = nil)
    return unless automergeable?

    MergeRequests::AutoMergeService.
      new(target_project, current_user).
      execute(self, commit_message)
  end

  def remove_source_branch?
    self.should_remove_source_branch && !self.source_project.root_ref?(self.source_branch) && !self.for_fork?
  end

  def open?
    opened? || reopened?
  end

  def work_in_progress?
    title =~ /\A\[?WIP\]?:? /i
  end

  def automergeable?
    open? && !work_in_progress? && can_be_merged?
  end

  def automerge_status
    if work_in_progress?
      "work_in_progress"
    else
      merge_status_name
    end
  end

  def mr_and_commit_notes
    commits_for_notes_limit = 100
    commit_ids = commits.last(commits_for_notes_limit).map(&:id)

    Note.where(
      "(project_id = :target_project_id AND noteable_type = 'MergeRequest' AND noteable_id = :mr_id) OR" +
      "(project_id = :source_project_id AND noteable_type = 'Commit' AND commit_id IN (:commit_ids))",
      mr_id: id,
      commit_ids: commit_ids,
      target_project_id: target_project_id,
      source_project_id: source_project_id
    )
  end

  def to_diff(current_user)
    Gitlab::Satellite::MergeAction.new(current_user, self).diff_in_satellite
  end

  def to_patch(current_user)
    Gitlab::Satellite::MergeAction.new(current_user, self).format_patch
  end

  def hook_attrs
    attrs = {
      source: source_project.hook_attrs,
      target: target_project.hook_attrs,
      last_commit: nil
    }

    unless last_commit.nil?
      attrs.merge!(last_commit: last_commit.hook_attrs)
    end

    attributes.merge!(attrs)
  end

  def for_fork?
    target_project != source_project
  end

  def project
    target_project
  end

  def closes_issues(current_user = self.author)
    if target_branch == project.default_branch
      issues = commits.flat_map { |c| c.closes_issues(current_user) }
      issues.push(*Gitlab::ClosingIssueExtractor.new(project, current_user).
                  closed_by_message(description))
      issues.uniq.sort_by(&:id)
    else
      []
    end
  end

  def target_project_path
    if target_project
      target_project.path_with_namespace
    else
      "(removed)"
    end
  end

  def source_project_path
    if source_project
      source_project.path_with_namespace
    else
      "(removed)"
    end
  end

  def source_project_namespace
    if source_project && source_project.namespace
      source_project.namespace.path
    else
      "(removed)"
    end
  end

  def target_project_namespace
    if target_project && target_project.namespace
      target_project.namespace.path
    else
      "(removed)"
    end
  end

  def source_branch_exists?
    return false unless self.source_project

    self.source_project.repository.branch_names.include?(self.source_branch)
  end

  def target_branch_exists?
    return false unless self.target_project

    self.target_project.repository.branch_names.include?(self.target_branch)
  end

  def reset_events_cache
    Event.reset_event_cache_for(self)
  end

  def merge_commit_message
    message = "Merge branch '#{source_branch}' into '#{target_branch}'"
    message << "\n\n"
    message << title.to_s
    message << "\n\n"
    message << description.to_s
    message << "\n\n"
    message << "See merge request !#{iid}"
    message
  end

  def target_branches
    if target_project.nil?
      []
    else
      target_project.repository.branch_names
    end
  end

  def source_branches
    if source_project.nil?
      []
    else
      source_project.repository.branch_names
    end
  end

  def locked_long_ago?
    return false unless locked?

    locked_at.nil? || locked_at < (Time.now - 1.day)
  end

  def has_ci?
    source_project.ci_service && commits.any?
  end

  def branch_missing?
    !source_branch_exists? || !target_branch_exists?
  end

  def can_be_merged_by?(user)
    ::Gitlab::GitAccess.new(user, project).can_push_to_branch?(target_branch)
  end

  def state_human_name
    if merged?
      "Merged"
    elsif closed?
      "Closed"
    else
      "Open"
    end
  end
end
