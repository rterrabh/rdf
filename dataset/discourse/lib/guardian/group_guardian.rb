module GroupGuardian

  def can_edit_group?(group)
    (group.managers.include?(user) || is_admin?) && !group.automatic
  end

end
