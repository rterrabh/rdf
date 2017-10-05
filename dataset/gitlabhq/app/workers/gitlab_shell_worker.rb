class GitlabShellWorker
  include Sidekiq::Worker
  include Gitlab::ShellAdapter

  sidekiq_options queue: :gitlab_shell

  def perform(action, *arg)
    #nodyna <ID:send-119> <SD COMPLEX (change-prone variables)>
    gitlab_shell.send(action, *arg)
  end
end
