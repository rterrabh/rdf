class DeleteUserService
  attr_accessor :current_user

  def initialize(current_user)
    @current_user = current_user
  end

  def execute(user)
    if user.solo_owned_groups.present?
      user.errors[:base] << 'You must transfer ownership or delete groups before you can remove user'
      user
    else
      user.personal_projects.each do |project|
        ::Projects::DestroyService.new(project, current_user, skip_repo: true).execute
      end

      user.destroy
    end
  end
end
