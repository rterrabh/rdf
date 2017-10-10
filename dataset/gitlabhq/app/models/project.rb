
require 'carrierwave/orm/activerecord'
require 'file_size_validator'

class Project < ActiveRecord::Base
  include Gitlab::ConfigHelper
  include Gitlab::ShellAdapter
  include Gitlab::VisibilityLevel
  include Referable
  include Sortable

  extend Gitlab::ConfigHelper
  extend Enumerize

  default_value_for :archived, false
  default_value_for :visibility_level, gitlab_config_features.visibility_level
  default_value_for :issues_enabled, gitlab_config_features.issues
  default_value_for :merge_requests_enabled, gitlab_config_features.merge_requests
  default_value_for :wiki_enabled, gitlab_config_features.wiki
  default_value_for :wall_enabled, false
  default_value_for :snippets_enabled, gitlab_config_features.snippets

  after_create :set_last_activity_at
  def set_last_activity_at
    update_column(:last_activity_at, self.created_at)
  end

  ActsAsTaggableOn.strict_case_match = true
  acts_as_taggable_on :tags

  attr_accessor :new_default_branch

  belongs_to :creator, foreign_key: 'creator_id', class_name: 'User'
  belongs_to :group, -> { where(type: Group) }, foreign_key: 'namespace_id'
  belongs_to :namespace

  has_one :last_event, -> {order 'events.created_at DESC'}, class_name: 'Event', foreign_key: 'project_id'

  has_many :services
  has_one :gitlab_ci_service, dependent: :destroy
  has_one :campfire_service, dependent: :destroy
  has_one :emails_on_push_service, dependent: :destroy
  has_one :irker_service, dependent: :destroy
  has_one :pivotaltracker_service, dependent: :destroy
  has_one :hipchat_service, dependent: :destroy
  has_one :flowdock_service, dependent: :destroy
  has_one :assembla_service, dependent: :destroy
  has_one :asana_service, dependent: :destroy
  has_one :gemnasium_service, dependent: :destroy
  has_one :slack_service, dependent: :destroy
  has_one :buildkite_service, dependent: :destroy
  has_one :bamboo_service, dependent: :destroy
  has_one :teamcity_service, dependent: :destroy
  has_one :pushover_service, dependent: :destroy
  has_one :jira_service, dependent: :destroy
  has_one :redmine_service, dependent: :destroy
  has_one :custom_issue_tracker_service, dependent: :destroy
  has_one :gitlab_issue_tracker_service, dependent: :destroy
  has_one :external_wiki_service, dependent: :destroy

  has_one :forked_project_link, dependent: :destroy, foreign_key: "forked_to_project_id"

  has_one :forked_from_project, through: :forked_project_link
  has_many :merge_requests,     dependent: :destroy, foreign_key: 'target_project_id'
  has_many :fork_merge_requests, foreign_key: 'source_project_id', class_name: MergeRequest
  has_many :issues,             dependent: :destroy
  has_many :labels,             dependent: :destroy
  has_many :services,           dependent: :destroy
  has_many :events,             dependent: :destroy
  has_many :milestones,         dependent: :destroy
  has_many :notes,              dependent: :destroy
  has_many :snippets,           dependent: :destroy, class_name: 'ProjectSnippet'
  has_many :hooks,              dependent: :destroy, class_name: 'ProjectHook'
  has_many :protected_branches, dependent: :destroy
  has_many :project_members, dependent: :destroy, as: :source, class_name: 'ProjectMember'
  has_many :users, through: :project_members
  has_many :deploy_keys_projects, dependent: :destroy
  has_many :deploy_keys, through: :deploy_keys_projects
  has_many :users_star_projects, dependent: :destroy
  has_many :starrers, through: :users_star_projects, source: :user

  has_one :import_data, dependent: :destroy, class_name: "ProjectImportData"

  delegate :name, to: :owner, allow_nil: true, prefix: true
  delegate :members, to: :team, prefix: true

  validates :creator, presence: true, on: :create
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :name,
    presence: true,
    length: { within: 0..255 },
    format: { with: Gitlab::Regex.project_name_regex,
              message: Gitlab::Regex.project_name_regex_message }
  validates :path,
    presence: true,
    length: { within: 0..255 },
    format: { with: Gitlab::Regex.project_path_regex,
              message: Gitlab::Regex.project_path_regex_message }
  validates :issues_enabled, :merge_requests_enabled,
            :wiki_enabled, inclusion: { in: [true, false] }
  validates :issues_tracker_id, length: { maximum: 255 }, allow_blank: true
  validates :namespace, presence: true
  validates_uniqueness_of :name, scope: :namespace_id
  validates_uniqueness_of :path, scope: :namespace_id
  validates :import_url,
    format: { with: /\A#{URI.regexp(%w(ssh git http https))}\z/, message: 'should be a valid url' },
    if: :import?
  validates :star_count, numericality: { greater_than_or_equal_to: 0 }
  validate :check_limit, on: :create
  validate :avatar_type,
    if: ->(project) { project.avatar.present? && project.avatar_changed? }
  validates :avatar, file_size: { maximum: 200.kilobytes.to_i }

  mount_uploader :avatar, AvatarUploader

  scope :sorted_by_activity, -> { reorder(last_activity_at: :desc) }
  scope :sorted_by_stars, -> { reorder('projects.star_count DESC') }
  scope :sorted_by_names, -> { joins(:namespace).reorder('namespaces.name ASC, projects.name ASC') }

  scope :without_user, ->(user)  { where('projects.id NOT IN (:ids)', ids: user.authorized_projects.map(&:id) ) }
  scope :without_team, ->(team) { team.projects.present? ? where('projects.id NOT IN (:ids)', ids: team.projects.map(&:id)) : scoped  }
  scope :not_in_group, ->(group) { where('projects.id NOT IN (:ids)', ids: group.project_ids ) }
  scope :in_namespace, ->(namespace_ids) { where(namespace_id: namespace_ids) }
  scope :in_group_namespace, -> { joins(:group) }
  scope :personal, ->(user) { where(namespace_id: user.namespace_id) }
  scope :joined, ->(user) { where('namespace_id != ?', user.namespace_id) }
  scope :public_only, -> { where(visibility_level: Project::PUBLIC) }
  scope :public_and_internal_only, -> { where(visibility_level: Project.public_and_internal_levels) }
  scope :non_archived, -> { where(archived: false) }

  state_machine :import_status, initial: :none do
    event :import_start do
      transition [:none, :finished] => :started
    end

    event :import_finish do
      transition started: :finished
    end

    event :import_fail do
      transition started: :failed
    end

    event :import_retry do
      transition failed: :started
    end

    state :started
    state :finished
    state :failed

    after_transition any => :started, do: :add_import_job
    after_transition any => :finished, do: :clear_import_data
  end

  class << self
    def public_and_internal_levels
      [Project::PUBLIC, Project::INTERNAL]
    end

    def abandoned
      where('projects.last_activity_at < ?', 6.months.ago)
    end

    def publicish(user)
      visibility_levels = [Project::PUBLIC]
      visibility_levels << Project::INTERNAL if user
      where(visibility_level: visibility_levels)
    end

    def with_push
      joins(:events).where('events.action = ?', Event::PUSHED)
    end

    def active
      joins(:issues, :notes, :merge_requests).order('issues.created_at, notes.created_at, merge_requests.created_at DESC')
    end

    def search(query)
      joins(:namespace).where('projects.archived = ?', false).
        where('LOWER(projects.name) LIKE :query OR
              LOWER(projects.path) LIKE :query OR
              LOWER(namespaces.name) LIKE :query OR
              LOWER(projects.description) LIKE :query',
              query: "%#{query.try(:downcase)}%")
    end

    def search_by_title(query)
      where('projects.archived = ?', false).where('LOWER(projects.name) LIKE :query', query: "%#{query.downcase}%")
    end

    def find_with_namespace(id)
      return nil unless id.include?('/')

      id = id.split('/')
      namespace = Namespace.find_by(path: id.first)
      return nil unless namespace

      where(namespace_id: namespace.id).find_by(path: id.second)
    end

    def visibility_levels
      Gitlab::VisibilityLevel.options
    end

    def sort(method)
      if method == 'repository_size_desc'
        reorder(repository_size: :desc, id: :desc)
      else
        order_by(method)
      end
    end

    def reference_pattern
      name_pattern = Gitlab::Regex::NAMESPACE_REGEX_STR
      %r{(?<project>#{name_pattern}/#{name_pattern})}
    end
  end

  def team
    @team ||= ProjectTeam.new(self)
  end

  def repository
    @repository ||= Repository.new(path_with_namespace, nil, self)
  end

  def commit(id = 'HEAD')
    repository.commit(id)
  end

  def saved?
    id && persisted?
  end

  def add_import_job
    RepositoryImportWorker.perform_in(2.seconds, id)
  end

  def clear_import_data
    self.import_data.destroy if self.import_data
  end

  def import?
    import_url.present?
  end

  def imported?
    import_finished?
  end

  def import_in_progress?
    import? && import_status == 'started'
  end

  def import_failed?
    import_status == 'failed'
  end

  def import_finished?
    import_status == 'finished'
  end

  def check_limit
    unless creator.can_create_project? or namespace.kind == 'group'
      errors[:limit_reached] << ("Your project limit is #{creator.projects_limit} projects! Please contact your administrator to increase it")
    end
  rescue
    errors[:base] << ("Can't check your ability to create project")
  end

  def to_param
    path
  end

  def to_reference(_from_project = nil)
    path_with_namespace
  end

  def web_url
    Rails.application.routes.url_helpers.namespace_project_url(self.namespace, self)
  end

  def web_url_without_protocol
    web_url.split('://')[1]
  end

  def build_commit_note(commit)
    notes.new(commit_id: commit.id, noteable_type: 'Commit')
  end

  def last_activity
    last_event
  end

  def last_activity_date
    last_activity_at || updated_at
  end

  def project_id
    self.id
  end

  def get_issue(issue_id)
    if default_issues_tracker?
      issues.find_by(iid: issue_id)
    else
      ExternalIssue.new(issue_id, self)
    end
  end

  def issue_exists?(issue_id)
    get_issue(issue_id)
  end

  def default_issue_tracker
    gitlab_issue_tracker_service || create_gitlab_issue_tracker_service
  end

  def issues_tracker
    if external_issue_tracker
      external_issue_tracker
    else
      default_issue_tracker
    end
  end

  def default_issues_tracker?
    !external_issue_tracker
  end

  def external_issues_trackers
    services.select(&:issue_tracker?).reject(&:default?)
  end

  def external_issue_tracker
    @external_issues_tracker ||= external_issues_trackers.select(&:activated?).first
  end

  def can_have_issues_tracker_id?
    self.issues_enabled && !self.default_issues_tracker?
  end

  def build_missing_services
    services_templates = Service.where(template: true)

    Service.available_services_names.each do |service_name|
      service = find_service(services, service_name)

      if service.nil?
        template = find_service(services_templates, service_name)

        if template.nil?
          #nodyna <send-509> <SD MODERATE (change-prone variables)>
          service = self.send :"create_#{service_name}_service"
        else
          Service.create_from_template(self.id, template)
        end
      end
    end
  end

  def find_service(list, name)
    list.find { |service| service.to_param == name }
  end

  def gitlab_ci?
    gitlab_ci_service && gitlab_ci_service.active
  end

  def ci_services
    services.select { |service| service.category == :ci }
  end

  def ci_service
    @ci_service ||= ci_services.select(&:activated?).first
  end

  def avatar_type
    unless self.avatar.image?
      self.errors.add :avatar, 'only images allowed'
    end
  end

  def avatar_in_git
    @avatar_file ||= 'logo.png' if repository.blob_at_branch('master', 'logo.png')
    @avatar_file ||= 'logo.jpg' if repository.blob_at_branch('master', 'logo.jpg')
    @avatar_file ||= 'logo.gif' if repository.blob_at_branch('master', 'logo.gif')
    @avatar_file
  end

  def avatar_url
    if avatar.present?
      [gitlab_config.url, avatar.url].join
    elsif avatar_in_git
      Rails.application.routes.url_helpers.namespace_project_avatar_url(namespace, self)
    end
  end

  def code
    path
  end

  def items_for(entity)
    case entity
    when 'issue' then
      issues
    when 'merge_request' then
      merge_requests
    end
  end

  def send_move_instructions
    NotificationService.new.project_was_moved(self)
  end

  def owner
    if group
      group
    else
      namespace.try(:owner)
    end
  end

  def project_member_by_name_or_email(name = nil, email = nil)
    user = users.where('name like ? or email like ?', name, email).first
    project_members.where(user: user) if user
  end

  def project_member_by_id(user_id)
    project_members.find_by(user_id: user_id)
  end

  def name_with_namespace
    @name_with_namespace ||= begin
                               if namespace
                                 namespace.human_name + ' / ' + name
                               else
                                 name
                               end
                             end
  end

  def path_with_namespace
    if namespace
      namespace.path + '/' + path
    else
      path
    end
  end

  def execute_hooks(data, hooks_scope = :push_hooks)
    #nodyna <send-510> <SD MODERATE (change-prone variables)>
    hooks.send(hooks_scope).each do |hook|
      hook.async_execute(data, hooks_scope.to_s)
    end
  end

  def execute_services(data, hooks_scope = :push_hooks)
    #nodyna <send-511> <SD MODERATE (change-prone variables)>
    services.send(hooks_scope).each do |service|
      service.async_execute(data)
    end
  end

  def update_merge_requests(oldrev, newrev, ref, user)
    MergeRequests::RefreshService.new(self, user).
      execute(oldrev, newrev, ref)
  end

  def valid_repo?
    repository.exists?
  rescue
    errors.add(:path, 'Invalid repository path')
    false
  end

  def empty_repo?
    !repository.exists? || repository.empty?
  end

  def ensure_satellite_exists
    self.satellite.create unless self.satellite.exists?
  end

  def satellite
    @satellite ||= Gitlab::Satellite::Satellite.new(self)
  end

  def repo
    repository.raw
  end

  def url_to_repo
    gitlab_shell.url_to_repo(path_with_namespace)
  end

  def namespace_dir
    namespace.try(:path) || ''
  end

  def repo_exists?
    @repo_exists ||= repository.exists?
  rescue
    @repo_exists = false
  end

  def open_branches
    all_branches = repository.branches

    if protected_branches.present?
      all_branches.reject! do |branch|
        protected_branches_names.include?(branch.name)
      end
    end

    all_branches
  end

  def protected_branches_names
    @protected_branches_names ||= protected_branches.map(&:name)
  end

  def root_ref?(branch)
    repository.root_ref == branch
  end

  def ssh_url_to_repo
    url_to_repo
  end

  def http_url_to_repo
    "#{web_url}.git"
  end

  def protected_branch?(branch_name)
    protected_branches_names.include?(branch_name)
  end

  def developers_can_push_to_protected_branch?(branch_name)
    protected_branches.any? { |pb| pb.name == branch_name && pb.developers_can_push }
  end

  def forked?
    !(forked_project_link.nil? || forked_project_link.forked_from_project.nil?)
  end

  def personal?
    !group
  end

  def rename_repo
    path_was = previous_changes['path'].first
    old_path_with_namespace = File.join(namespace_dir, path_was)
    new_path_with_namespace = File.join(namespace_dir, path)

    if gitlab_shell.mv_repository(old_path_with_namespace, new_path_with_namespace)
      begin
        gitlab_shell.mv_repository("#{old_path_with_namespace}.wiki", "#{new_path_with_namespace}.wiki")
        gitlab_shell.rm_satellites(old_path_with_namespace)
        ensure_satellite_exists
        send_move_instructions
        reset_events_cache
      rescue
        false
      end
    else
      raise Exception.new('repository cannot be renamed')
    end
  end

  def hook_attrs
    {
      name: name,
      ssh_url: ssh_url_to_repo,
      http_url: http_url_to_repo,
      namespace: namespace.name,
      visibility_level: visibility_level
    }
  end

  def reset_events_cache
    Event.where(project_id: self.id).
      order('id DESC').limit(100).
      update_all(updated_at: Time.now)
  end

  def project_member(user)
    project_members.where(user_id: user).first
  end

  def default_branch
    @default_branch ||= repository.root_ref if repository.exists?
  end

  def reload_default_branch
    @default_branch = nil
    default_branch
  end

  def visibility_level_field
    visibility_level
  end

  def archive!
    update_attribute(:archived, true)
  end

  def unarchive!
    update_attribute(:archived, false)
  end

  def change_head(branch)
    gitlab_shell.update_repository_head(self.path_with_namespace, branch)
    reload_default_branch
  end

  def forked_from?(project)
    forked? && project == forked_from_project
  end

  def update_repository_size
    update_attribute(:repository_size, repository.size)
  end

  def update_commit_count
    update_attribute(:commit_count, repository.commit_count)
  end

  def forks_count
    ForkedProjectLink.where(forked_from_project_id: self.id).count
  end

  def find_label(name)
    labels.find_by(name: name)
  end

  def origin_merge_requests
    merge_requests.where(source_project_id: self.id)
  end

  def create_repository
    if forked?
      if gitlab_shell.fork_repository(forked_from_project.path_with_namespace, self.namespace.path)
        ensure_satellite_exists
        true
      else
        errors.add(:base, 'Failed to fork repository via gitlab-shell')
        false
      end
    else
      if gitlab_shell.add_repository(path_with_namespace)
        true
      else
        errors.add(:base, 'Failed to create repository via gitlab-shell')
        false
      end
    end
  end

  def repository_exists?
    !!repository.exists?
  end

  def create_wiki
    ProjectWiki.new(self, self.owner).wiki
    true
  rescue ProjectWiki::CouldNotCreateWikiError => ex
    errors.add(:base, 'Failed create wiki')
    false
  end
end
