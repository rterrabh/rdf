class GroupsFinder
  def execute(current_user, options = {})
    all_groups(current_user)
  end

  private

  def all_groups(current_user)
    if current_user
      if current_user.authorized_groups.any?
        group_ids = Project.public_and_internal_only.pluck(:namespace_id) +
          current_user.authorized_groups.pluck(:id)
        Group.where(id: group_ids)
      else
        Group.where(id: Project.public_and_internal_only.pluck(:namespace_id))
      end
    else
      Group.where(id: Project.public_only.pluck(:namespace_id))
    end
  end
end
