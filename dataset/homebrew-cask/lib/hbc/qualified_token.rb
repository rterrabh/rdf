module Hbc::QualifiedToken
  def self.repo_prefix
    'homebrew-'
  end

  def self.user_regexp
    %r{[a-z_\-]+}
  end

  def self.repo_regexp
    %r{(?:#{repo_prefix})?\w+}
  end

  def self.token_regexp
    %r{[a-z0-9\-]+}
  end

  def self.tap_regexp
    %r{#{user_regexp}[/\-]#{repo_regexp}}
  end

  def self.qualified_token_regexp
    @qualified_token_regexp ||= %r{#{tap_regexp}/#{token_regexp}}
  end

  def self.parse(arg)
    return nil if ! arg.kind_of?(String)
    return nil if ! arg.downcase.match(%r{^#{qualified_token_regexp}$})
    path_elements = arg.downcase.split('/')
    if path_elements.count == 2
      token = path_elements[1]
      dash_elements = path_elements[0].split('-')
      repo = dash_elements.pop
      dash_elements.pop if dash_elements.count > 1 and dash_elements[-1] + '-' == repo_prefix
      user = dash_elements.join('-')
    else
      user, repo, token = path_elements
    end
    repo.sub!(%r{^#{repo_prefix}}, '')
    odebug "[user, repo, token] might be [#{user}, #{repo}, #{token}]"
    [user, repo, token]
  end
end
