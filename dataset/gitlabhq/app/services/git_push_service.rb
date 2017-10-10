class GitPushService
  attr_accessor :project, :user, :push_data, :push_commits
  include Gitlab::CurrentSettings
  include Gitlab::Access

  def execute(project, user, oldrev, newrev, ref)
    @project, @user = project, user

    project.ensure_satellite_exists
    project.repository.expire_cache

    if push_remove_branch?(ref, newrev)
      @push_commits = []
    elsif push_to_new_branch?(ref, oldrev)
      if is_default_branch?(ref)
        @push_commits = project.repository.commits(newrev)

        branch_name = Gitlab::Git.ref_name(ref)
        project.change_head(branch_name)

        if (current_application_settings.default_branch_protection != PROTECTION_NONE)
          developers_can_push = current_application_settings.default_branch_protection == PROTECTION_DEV_CAN_PUSH ? true : false
          project.protected_branches.create({ name: project.default_branch, developers_can_push: developers_can_push })
        end
      else
        @push_commits = project.repository.commits_between(project.default_branch, newrev)

        process_commit_messages(ref)
      end
    elsif push_to_existing_branch?(ref, oldrev)
      @push_commits = project.repository.commits_between(oldrev, newrev)
      project.update_merge_requests(oldrev, newrev, ref, @user)
      process_commit_messages(ref)
    end

    @push_data = build_push_data(oldrev, newrev, ref)

    EventCreateService.new.push(project, user, @push_data)
    project.execute_hooks(@push_data.dup, :push_hooks)
    project.execute_services(@push_data.dup, :push_hooks)
    ProjectCacheWorker.perform_async(project.id)
  end

  protected

  def process_commit_messages(ref)
    is_default_branch = is_default_branch?(ref)

    @push_commits.each do |commit|
      issues_to_close = commit.closes_issues(user)

      author = nil

      if issues_to_close.present? && is_default_branch
        author ||= commit_user(commit)

        issues_to_close.each do |issue|
          Issues::CloseService.new(project, author, {}).execute(issue, commit)
        end
      end

      if project.default_issues_tracker?
        create_cross_reference_notes(commit, issues_to_close)
      end
    end
  end

  def create_cross_reference_notes(commit, issues_to_close)
    refs = commit.references(project, user) - issues_to_close
    refs.reject! { |r| commit.has_mentioned?(r) }

    if refs.present?
      author ||= commit_user(commit)

      refs.each do |r|
        SystemNoteService.cross_reference(r, commit, author)
      end
    end
  end

  def build_push_data(oldrev, newrev, ref)
    Gitlab::PushDataBuilder.
      build(project, user, oldrev, newrev, ref, push_commits)
  end

  def push_to_existing_branch?(ref, oldrev)
    Gitlab::Git.branch_ref?(ref) && !Gitlab::Git.blank_ref?(oldrev)
  end

  def push_to_new_branch?(ref, oldrev)
    Gitlab::Git.branch_ref?(ref) && Gitlab::Git.blank_ref?(oldrev)
  end

  def push_remove_branch?(ref, newrev)
    Gitlab::Git.branch_ref?(ref) && Gitlab::Git.blank_ref?(newrev)
  end

  def push_to_branch?(ref)
    Gitlab::Git.branch_ref?(ref)
  end

  def is_default_branch?(ref)
    Gitlab::Git.branch_ref?(ref) && Gitlab::Git.ref_name(ref) == project.default_branch
  end

  def commit_user(commit)
    commit.author || user
  end
end
