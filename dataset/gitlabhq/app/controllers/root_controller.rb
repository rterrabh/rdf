class RootController < DashboardController
  before_action :redirect_to_custom_dashboard, only: [:show]

  def show
    super
  end

  private

  def redirect_to_custom_dashboard
    return unless current_user

    case current_user.dashboard
    when 'stars'
      redirect_to starred_dashboard_projects_path
    else
      return
    end
  end
end
