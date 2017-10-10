class ProjectsFinder
  def execute(current_user, options = {})
    group = options[:group]

    if group
      group_projects(current_user, group)
    else
      all_projects(current_user)
    end
  end

  private

  def group_projects(current_user, group)
    if current_user
      if group.users.include?(current_user)
        group.projects
      else
        projects_members = ProjectMember.in_projects(group.projects).
          with_user(current_user)

        if projects_members.any?
          group.projects.where(
            "projects.id IN (?) OR projects.visibility_level IN (?)",
            projects_members.pluck(:source_id),
            Project.public_and_internal_levels
          )
        else
          group.projects.public_and_internal_only
        end
      end
    else
      group.projects.public_only
    end
  end

  def all_projects(current_user)
    if current_user
      if current_user.authorized_projects.any?
        Project.where(
          "projects.id IN (?) OR projects.visibility_level IN (?)",
          current_user.authorized_projects.pluck(:id),
          Project.public_and_internal_levels
        )
      else
        Project.public_and_internal_only
      end
    else
      Project.public_only
    end
  end
end
