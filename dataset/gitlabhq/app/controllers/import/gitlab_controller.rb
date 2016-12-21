class Import::GitlabController < Import::BaseController
  before_action :verify_gitlab_import_enabled
  before_action :gitlab_auth, except: :callback

  rescue_from OAuth2::Error, with: :gitlab_unauthorized

  def callback
    token = client.get_token(params[:code], callback_import_gitlab_url)
    current_user.gitlab_access_token = token
    current_user.save
    redirect_to status_import_gitlab_url
  end

  def status
    @repos = client.projects

    @already_added_projects = current_user.created_projects.where(import_type: "gitlab")
    already_added_projects_names = @already_added_projects.pluck(:import_source)

    @repos = @repos.to_a.reject{ |repo| already_added_projects_names.include? repo["path_with_namespace"] }
  end

  def jobs
    jobs = current_user.created_projects.where(import_type: "gitlab").to_json(only: [:id, :import_status])
    render json: jobs
  end

  def create
    @repo_id = params[:repo_id].to_i
    repo = client.project(@repo_id)
    @project_name = repo["name"]

    repo_owner = repo["namespace"]["path"]
    repo_owner = current_user.username if repo_owner == client.user["username"]
    @target_namespace = params[:new_namespace].presence || repo_owner

    namespace = get_or_create_namespace || (render and return)

    @project = Gitlab::GitlabImport::ProjectCreator.new(repo, namespace, current_user).execute
  end

  private

  def client
    @client ||= Gitlab::GitlabImport::Client.new(current_user.gitlab_access_token)
  end

  def verify_gitlab_import_enabled
    not_found! unless gitlab_import_enabled?
  end

  def gitlab_auth
    if current_user.gitlab_access_token.blank?
      go_to_gitlab_for_permissions
    end
  end

  def go_to_gitlab_for_permissions
    redirect_to client.authorize_url(callback_import_gitlab_url)
  end

  def gitlab_unauthorized
    go_to_gitlab_for_permissions
  end
end
