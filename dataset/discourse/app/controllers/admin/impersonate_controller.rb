class Admin::ImpersonateController < Admin::AdminController

  def create
    params.require(:username_or_email)

    user = User.find_by_username_or_email(params[:username_or_email])
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_impersonate!(user)

    StaffActionLogger.new(current_user).log_impersonate(user)

    log_on_user(user)

    render nothing: true
  end

end
