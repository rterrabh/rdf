class DestroyGroupService
  attr_accessor :group, :current_user

  def initialize(group, user)
    @group, @current_user = group, user
  end

  def execute
    @group.projects.each do |project|
      ::Projects::DestroyService.new(project, current_user, skip_repo: true).execute
    end

    @group.destroy
  end
end
