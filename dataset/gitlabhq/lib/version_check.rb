require "base64"

class VersionCheck
  def data
    { version: Gitlab::VERSION }
  end

  def url
    encoded_data = Base64.urlsafe_encode64(data.to_json)
    "#{host}?gitlab_info=#{encoded_data}"
  end

  def host
    'https://version.gitlab.com/check.png'
  end
end
