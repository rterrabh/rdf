
class Service < ActiveRecord::Base
  include Sortable
  serialize :properties, JSON

  default_value_for :active, false
  default_value_for :push_events, true
  default_value_for :issues_events, true
  default_value_for :merge_requests_events, true
  default_value_for :tag_push_events, true
  default_value_for :note_events, true

  after_initialize :initialize_properties

  belongs_to :project
  has_one :service_hook

  validates :project_id, presence: true, unless: Proc.new { |service| service.template? }

  scope :visible, -> { where.not(type: 'GitlabIssueTrackerService') }

  scope :push_hooks, -> { where(push_events: true, active: true) }
  scope :tag_push_hooks, -> { where(tag_push_events: true, active: true) }
  scope :issue_hooks, -> { where(issues_events: true, active: true) }
  scope :merge_request_hooks, -> { where(merge_requests_events: true, active: true) }
  scope :note_hooks, -> { where(note_events: true, active: true) }

  def activated?
    active
  end

  def template?
    template
  end

  def category
    :common
  end

  def initialize_properties
    self.properties = {} if properties.nil?
  end

  def title
  end

  def description
  end

  def help
  end

  def to_param
  end

  def fields
    []
  end

  def supported_events
    %w(push tag_push issue merge_request)
  end

  def execute(data)
  end

  def test(data)
    result = execute(data)
    { success: result.present?, result: result }
  end

  def can_test?
    !project.empty_repo?
  end

  def self.prop_accessor(*args)
    args.each do |arg|
      #nodyna <class_eval-502> <not yet classified>
      class_eval %{
        def #{arg}
          properties['#{arg}']
        end

        def #{arg}=(value)
          self.properties['#{arg}'] = value
        end
      }
    end
  end

  def async_execute(data)
    return unless supported_events.include?(data[:object_kind])

    Sidekiq::Client.enqueue(ProjectServiceWorker, id, data)
  end

  def issue_tracker?
    self.category == :issue_tracker
  end

  def self.available_services_names
    %w(
      asana
      assembla
      bamboo
      buildkite
      campfire
      custom_issue_tracker
      emails_on_push
      external_wiki
      flowdock
      gemnasium
      gitlab_ci
      hipchat
      irker
      jira
      pivotaltracker
      pushover
      redmine
      slack
      teamcity
    )
  end

  def self.create_from_template(project_id, template)
    service = template.dup
    service.template = false
    service.project_id = project_id
    service if service.save
  end
end
