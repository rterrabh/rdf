class GitlabShellWorker
  include Sidekiq::Worker
  include Gitlab::ShellAdapter

  sidekiq_options queue: :gitlab_shell

  def perform(action, *arg)
    #nodyna <ID:send-119> <send VERY HIGH ex3>
    gitlab_shell.send(action, *arg)
  end
end
