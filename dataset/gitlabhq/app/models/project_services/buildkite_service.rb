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

require "addressable/uri"

class BuildkiteService < CiService
  ENDPOINT = "https://buildkite.com"

  prop_accessor :project_url, :token

  validates :project_url, presence: true, if: :activated?
  validates :token, presence: true, if: :activated?

  after_save :compose_service_hook, if: :activated?

  def webhook_url
    "#{buildkite_endpoint('webhook')}/deliver/#{webhook_token}"
  end

  def compose_service_hook
    hook = service_hook || build_service_hook
    hook.url = webhook_url
    hook.save
  end

  def supported_events
    %w(push)
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])

    service_hook.execute(data)
  end

  def commit_status(sha, ref)
    response = HTTParty.get(commit_status_path(sha), verify: false)

    if response.code == 200 && response['status']
      response['status']
    else
      :error
    end
  end

  def commit_status_path(sha)
    "#{buildkite_endpoint('gitlab')}/status/#{status_token}.json?commit=#{sha}"
  end

  def build_page(sha, ref)
    "#{project_url}/builds?commit=#{sha}"
  end

  def builds_path
    "#{project_url}/builds?branch=#{project.default_branch}"
  end

  def status_img_path
    "#{buildkite_endpoint('badge')}/#{status_token}.svg"
  end

  def title
    'Buildkite'
  end

  def description
    'Continuous integration and deployments'
  end

  def to_param
    'buildkite'
  end

  def fields
    [
      { type: 'text',
        name: 'token',
        placeholder: 'Buildkite project GitLab token' },

      { type: 'text',
        name: 'project_url',
        placeholder: "#{ENDPOINT}/example/project" }
    ]
  end

  private

  def webhook_token
    token_parts.first
  end

  def status_token
    token_parts.second
  end

  def token_parts
    if token.present?
      token.split(':')
    else
      []
    end
  end

  def buildkite_endpoint(subdomain = nil)
    if subdomain.present?
      uri = Addressable::URI.parse(ENDPOINT)
      new_endpoint = "#{uri.scheme || 'http'}://#{subdomain}.#{uri.host}"

      if uri.port.present?
        "#{new_endpoint}:#{uri.port}"
      else
        new_endpoint
      end
    else
      ENDPOINT
    end
  end
end
