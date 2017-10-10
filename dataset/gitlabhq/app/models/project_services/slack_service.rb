
class SlackService < Service
  prop_accessor :webhook, :username, :channel
  validates :webhook, presence: true, if: :activated?

  def title
    'Slack'
  end

  def description
    'A team communication tool for the 21st century'
  end

  def to_param
    'slack'
  end

  def fields
    [
      { type: 'text', name: 'webhook',
        placeholder: 'https://hooks.slack.com/services/...' },
      { type: 'text', name: 'username', placeholder: 'username' },
      { type: 'text', name: 'channel', placeholder: '#channel' }
    ]
  end

  def supported_events
    %w(push issue merge_request note tag_push)
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])
    return unless webhook.present?

    object_kind = data[:object_kind]

    data = data.merge(
      project_url: project_url,
      project_name: project_name
    )


    message = \
      case object_kind
      when "push", "tag_push"
        PushMessage.new(data)
      when "issue"
        IssueMessage.new(data) unless is_update?(data)
      when "merge_request"
        MergeMessage.new(data) unless is_update?(data)
      when "note"
        NoteMessage.new(data)
      end

    opt = {}
    opt[:channel] = channel if channel
    opt[:username] = username if username

    if message
      notifier = Slack::Notifier.new(webhook, opt)
      notifier.ping(message.pretext, attachments: message.attachments)
    end
  end

  private

  def project_name
    project.name_with_namespace.gsub(/\s/, '')
  end

  def project_url
    project.web_url
  end

  def is_update?(data)
    data[:object_attributes][:action] == 'update'
  end
end

require "slack_service/issue_message"
require "slack_service/push_message"
require "slack_service/merge_message"
require "slack_service/note_message"
