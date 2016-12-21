class Import::GoogleCodeController < Import::BaseController
  before_action :user_map, only: [:new_user_map, :create_user_map]

  def new

  end

  def callback
    dump_file = params[:dump_file]

    unless dump_file.respond_to?(:read)
      return redirect_to :back, alert: "You need to upload a Google Takeout archive."
    end

    begin
      dump = JSON.parse(dump_file.read)
    rescue
      return redirect_to :back, alert: "The uploaded file is not a valid Google Takeout archive."
    end

    client = Gitlab::GoogleCodeImport::Client.new(dump)
    unless client.valid?
      return redirect_to :back, alert: "The uploaded file is not a valid Google Takeout archive."
    end

    session[:google_code_dump] = dump

    if params[:create_user_map] == "1"
      redirect_to new_user_map_import_google_code_path
    else
      redirect_to status_import_google_code_path
    end
  end

  def new_user_map

  end

  def create_user_map
    user_map_json = params[:user_map]
    user_map_json = "{}" if user_map_json.blank?

    begin
      user_map = JSON.parse(user_map_json)
    rescue
      flash.now[:alert] = "The entered user map is not a valid JSON user map."

      render "new_user_map" and return
    end

    unless user_map.is_a?(Hash) && user_map.all? { |k, v| k.is_a?(String) && v.is_a?(String) }
      flash.now[:alert] = "The entered user map is not a valid JSON user map."

      render "new_user_map" and return
    end

    # This is the default, so let's not save it into the database.
    user_map.reject! do |key, value|
      value == Gitlab::GoogleCodeImport::Client.mask_email(key)
    end

    session[:google_code_user_map] = user_map

    flash[:notice] = "The user map has been saved. Continue by selecting the projects you want to import."

    redirect_to status_import_google_code_path
  end

  def status
    unless client.valid?
      return redirect_to new_import_google_code_path
    end

    @repos = client.repos
    @incompatible_repos = client.incompatible_repos

    @already_added_projects = current_user.created_projects.where(import_type: "google_code")
    already_added_projects_names = @already_added_projects.pluck(:import_source)

    @repos.reject! { |repo| already_added_projects_names.include? repo.name }
  end

  def jobs
    jobs = current_user.created_projects.where(import_type: "google_code").to_json(only: [:id, :import_status])
    render json: jobs
  end

  def create
    @repo_id = params[:repo_id]
    repo = client.repo(@repo_id)
    @target_namespace = current_user.namespace
    @project_name = repo.name

    namespace = @target_namespace

    user_map = session[:google_code_user_map]

    @project = Gitlab::GoogleCodeImport::ProjectCreator.new(repo, namespace, current_user, user_map).execute
  end

  private

  def client
    @client ||= Gitlab::GoogleCodeImport::Client.new(session[:google_code_dump])
  end

  def user_map
    @user_map ||= begin
      user_map = client.user_map

      stored_user_map = session[:google_code_user_map]
      user_map.update(stored_user_map) if stored_user_map

      Hash[user_map.sort]
    end
  end
end
