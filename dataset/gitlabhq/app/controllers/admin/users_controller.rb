class Admin::UsersController < Admin::ApplicationController
  before_action :user, except: [:index, :new, :create]

  def index
    @users = User.order_name_asc.filter(params[:filter])
    @users = @users.search(params[:name]) if params[:name].present?
    @users = @users.sort(@sort = params[:sort])
    @users = @users.page(params[:page])
  end

  def show
  end

  def projects
    @personal_projects = user.personal_projects
    @joined_projects = user.projects.joined(@user)
  end

  def groups
  end

  def keys
    @keys = user.keys
  end

  def new
    @user = User.new
  end

  def edit
    user
  end

  def block
    if user.block
      redirect_to :back, notice: "Successfully blocked"
    else
      redirect_to :back, alert: "Error occurred. User was not blocked"
    end
  end

  def unblock
    if user.activate
      redirect_to :back, notice: "Successfully unblocked"
    else
      redirect_to :back, alert: "Error occurred. User was not unblocked"
    end
  end

  def unlock
    if user.unlock_access!
      redirect_to :back, alert: "Successfully unlocked"
    else
      redirect_to :back, alert: "Error occurred. User was not unlocked"
    end
  end

  def confirm
    if user.confirm!
      redirect_to :back, notice: "Successfully confirmed"
    else
      redirect_to :back, alert: "Error occurred. User was not confirmed"
    end
  end

  def disable_two_factor
    user.disable_two_factor!
    redirect_to admin_user_path(user),
      notice: 'Two-factor Authentication has been disabled for this user'
  end

  def create
    opts = {
      force_random_password: true,
      password_expires_at: nil
    }

    @user = User.new(user_params.merge(opts))
    @user.created_by_id = current_user.id
    @user.generate_password
    @user.generate_reset_token
    @user.skip_confirmation!

    respond_to do |format|
      if @user.save
        format.html { redirect_to [:admin, @user], notice: 'User was successfully created.' }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render "new" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    user_params_with_pass = user_params.dup

    if params[:user][:password].present?
      user_params_with_pass.merge!(
        password: params[:user][:password],
        password_confirmation: params[:user][:password_confirmation],
      )
    end

    respond_to do |format|
      user.skip_reconfirmation!
      if user.update_attributes(user_params_with_pass)
        format.html { redirect_to [:admin, user], notice: 'User was successfully updated.' }
        format.json { head :ok }
      else
        # restore username to keep form action url.
        user.username = params[:id]
        format.html { render "edit" }
        format.json { render json: user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    DeleteUserService.new(current_user).execute(user)

    respond_to do |format|
      format.html { redirect_to admin_users_path }
      format.json { head :ok }
    end
  end

  def remove_email
    email = user.emails.find(params[:email_id])
    email.destroy

    user.update_secondary_emails!

    respond_to do |format|
      format.html { redirect_to :back, notice: "Successfully removed email." }
      format.js { render nothing: true }
    end
  end

  protected

  def user
    @user ||= User.find_by!(username: params[:id])
  end

  def user_params
    params.require(:user).permit(
      :email, :remember_me, :bio, :name, :username,
      :skype, :linkedin, :twitter, :website_url, :color_scheme_id, :theme_id, :force_random_password,
      :extern_uid, :provider, :password_expires_at, :avatar, :hide_no_ssh_key, :hide_no_password,
      :projects_limit, :can_create_group, :admin, :key_id
    )
  end
end
