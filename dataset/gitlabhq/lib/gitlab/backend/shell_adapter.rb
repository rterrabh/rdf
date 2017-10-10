module Gitlab
  module ShellAdapter
    def gitlab_shell
      Gitlab::Shell.new
    end
  end
end
