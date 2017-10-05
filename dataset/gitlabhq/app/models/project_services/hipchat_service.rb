# == Schema Information
#
# Table name: services
#
#  id                    :integer          not null, primary key
#  type                  :string(255)
#  title                 :string(255)
#  project_id            :integer
#  created_at            :datetime
#  updated_at            :datetime
#  active                :boolean          default(FALSE), not null
#  properties            :text
#  template              :boolean          default(FALSE)
#  push_events           :boolean          default(TRUE)
#  issues_events         :boolean          default(TRUE)
#  merge_requests_events :boolean          default(TRUE)
#  tag_push_events       :boolean          default(TRUE)
#  note_events           :boolean          default(TRUE), not null
#

class HipchatService < Service
  MAX_COMMITS = 3

  prop_accessor :token, :room, :server, :notify, :color, :api_version
  validates :token, presence: true, if: :activated?

  def title
    'HipChat'
  end

  def description
    'Private group chat and IM'
  end

  def to_param
    'hipchat'
  end

  def fields
    [
      { type: 'text', name: 'token',     placeholder: 'Room token' },
      { type: 'text', name: 'room',      placeholder: 'Room name or ID' },
      { type: 'checkbox', name: 'notify' },
      { type: 'select', name: 'color', choices: ['yellow', 'red', 'green', 'purple', 'gray', 'random'] },
      { type: 'text', name: 'api_version',
        placeholder: 'Leave blank for default (v2)' },
      { type: 'text', name: 'server',
        placeholder: 'Leave blank for default. https://hipchat.example.com' }
    ]
  end

  def supported_events
    %w(push issue merge_request note tag_push)
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])
    message = create_message(data)
    return unless message.present?
    #nodyna <ID:send-79> <SD COMPLEX (private methods)>
    gate[room].send('GitLab', message, message_options)
  end

  def test(data)
    begin
      result = execute(data)
    rescue StandardError => error
      return { success: false, result: error }
    end

    { success: true, result: result }
  end

  private

  def gate
    options = { api_version: api_version.present? ? api_version : 'v2' }
    options[:server_url] = server unless server.blank?
    @gate ||= HipChat::Client.new(token, options)
  end

  def message_options
    { notify: notify.present? && notify == '1', color: color || 'yellow' }
  end

  def create_message(data)
    object_kind = data[:object_kind]

    message = \
      case object_kind
      when "push", "tag_push"
        create_push_message(data)
      when "issue"
        create_issue_message(data) unless is_update?(data)
      when "merge_request"
        create_merge_request_message(data) unless is_update?(data)
      when "note"
        create_note_message(data)
      end
  end

  def create_push_message(push)
    ref_type = Gitlab::Git.tag_ref?(push[:ref]) ? 'tag' : 'branch'
    ref = Gitlab::Git.ref_name(push[:ref])

    before = push[:before]
    after = push[:after]

    message = ""
    message << "#{push[:user_name]} "
    if Gitlab::Git.blank_ref?(before)
      message << "pushed new #{ref_type} <a href=\""\
                 "#{project_url}/commits/#{URI.escape(ref)}\">#{ref}</a>"\
                 " to #{project_link}\n"
    elsif Gitlab::Git.blank_ref?(after)
      message << "removed #{ref_type} <b>#{ref}</b> from <a href=\"#{project.web_url}\">#{project_name}</a> \n"
    else
      message << "pushed to #{ref_type} <a href=\""\
                  "#{project.web_url}/commits/#{URI.escape(ref)}\">#{ref}</a> "
      message << "of <a href=\"#{project.web_url}\">#{project.name_with_namespace.gsub!(/\s/,'')}</a> "
      message << "(<a href=\"#{project.web_url}/compare/#{before}...#{after}\">Compare changes</a>)"

      push[:commits].take(MAX_COMMITS).each do |commit|
        message << "<br /> - #{commit[:message].lines.first} (<a href=\"#{commit[:url]}\">#{commit[:id][0..5]}</a>)"
      end

      if push[:commits].count > MAX_COMMITS
        message << "<br />... #{push[:commits].count - MAX_COMMITS} more commits"
      end
    end

    message
  end

  def format_body(body)
    if body
      body = body.truncate(200, separator: ' ', omission: '...')
    end

    "<pre>#{body}</pre>"
  end

  def create_issue_message(data)
    user_name = data[:user][:name]

    obj_attr = data[:object_attributes]
    obj_attr = HashWithIndifferentAccess.new(obj_attr)
    title = obj_attr[:title]
    state = obj_attr[:state]
    issue_iid = obj_attr[:iid]
    issue_url = obj_attr[:url]
    description = obj_attr[:description]

    issue_link = "<a href=\"#{issue_url}\">issue ##{issue_iid}</a>"
    message = "#{user_name} #{state} #{issue_link} in #{project_link}: <b>#{title}</b>"

    if description
      description = format_body(description)
      message << description
    end

    message
  end

  def create_merge_request_message(data)
    user_name = data[:user][:name]

    obj_attr = data[:object_attributes]
    obj_attr = HashWithIndifferentAccess.new(obj_attr)
    merge_request_id = obj_attr[:iid]
    source_branch = obj_attr[:source_branch]
    target_branch = obj_attr[:target_branch]
    state = obj_attr[:state]
    description = obj_attr[:description]
    title = obj_attr[:title]

    merge_request_url = "#{project_url}/merge_requests/#{merge_request_id}"
    merge_request_link = "<a href=\"#{merge_request_url}\">merge request ##{merge_request_id}</a>"
    message = "#{user_name} #{state} #{merge_request_link} in " \
      "#{project_link}: <b>#{title}</b>"

    if description
      description = format_body(description)
      message << description
    end

    message
  end

  def format_title(title)
    "<b>" + title.lines.first.chomp + "</b>"
  end

  def create_note_message(data)
    data = HashWithIndifferentAccess.new(data)
    user_name = data[:user][:name]

    repo_attr = HashWithIndifferentAccess.new(data[:repository])

    obj_attr = HashWithIndifferentAccess.new(data[:object_attributes])
    note = obj_attr[:note]
    note_url = obj_attr[:url]
    noteable_type = obj_attr[:noteable_type]

    case noteable_type
    when "Commit"
      commit_attr = HashWithIndifferentAccess.new(data[:commit])
      subject_desc = commit_attr[:id]
      subject_desc = Commit.truncate_sha(subject_desc)
      subject_type = "commit"
      title = format_title(commit_attr[:message])
    when "Issue"
      subj_attr = HashWithIndifferentAccess.new(data[:issue])
      subject_id = subj_attr[:iid]
      subject_desc = "##{subject_id}"
      subject_type = "issue"
      title = format_title(subj_attr[:title])
    when "MergeRequest"
      subj_attr = HashWithIndifferentAccess.new(data[:merge_request])
      subject_id = subj_attr[:iid]
      subject_desc = "##{subject_id}"
      subject_type = "merge request"
      title = format_title(subj_attr[:title])
    when "Snippet"
      subj_attr = HashWithIndifferentAccess.new(data[:snippet])
      subject_id = subj_attr[:id]
      subject_desc = "##{subject_id}"
      subject_type = "snippet"
      title = format_title(subj_attr[:title])
    end

    subject_html = "<a href=\"#{note_url}\">#{subject_type} #{subject_desc}</a>"
    message = "#{user_name} commented on #{subject_html} in #{project_link}: "
    message << title

    if note
      note = format_body(note)
      message << note
    end

    message
  end

  def project_name
    project.name_with_namespace.gsub(/\s/, '')
  end

  def project_url
    project.web_url
  end

  def project_link
    "<a href=\"#{project_url}\">#{project_name}</a>"
  end

  def is_update?(data)
    data[:object_attributes][:action] == 'update'
  end
end
