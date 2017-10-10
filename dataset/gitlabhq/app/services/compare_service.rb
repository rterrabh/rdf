class CompareService
  def execute(current_user, source_project, source_branch, target_project, target_branch)
    if target_project == source_project
      Gitlab::CompareResult.new(
        Gitlab::Git::Compare.new(
          target_project.repository.raw_repository,
          target_branch,
          source_branch,
        )
      )
    else
      Gitlab::Satellite::CompareAction.new(
        current_user,
        target_project,
        target_branch,
        source_project,
        source_branch
      ).result
    end
  end
end
