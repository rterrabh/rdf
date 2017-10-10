require 'mime/types'

module API
  class Branches < Grape::API
    before { authenticate! }
    before { authorize! :download_code, user_project }

    resource :projects do
      get ":id/repository/branches" do
        branches = user_project.repository.branches.sort_by(&:name)
        present branches, with: Entities::RepoObject, project: user_project
      end

      get ':id/repository/branches/:branch', requirements: { branch: /.*/ } do
        @branch = user_project.repository.branches.find { |item| item.name == params[:branch] }
        not_found!("Branch") unless @branch
        present @branch, with: Entities::RepoObject, project: user_project
      end

      put ':id/repository/branches/:branch/protect',
          requirements: { branch: /.*/ } do

        authorize_admin_project

        @branch = user_project.repository.find_branch(params[:branch])
        not_found!("Branch") unless @branch
        protected_branch = user_project.protected_branches.find_by(name: @branch.name)
        user_project.protected_branches.create(name: @branch.name) unless protected_branch

        present @branch, with: Entities::RepoObject, project: user_project
      end

      put ':id/repository/branches/:branch/unprotect',
          requirements: { branch: /.*/ } do

        authorize_admin_project

        @branch = user_project.repository.find_branch(params[:branch])
        not_found!("Branch does not exist") unless @branch
        protected_branch = user_project.protected_branches.find_by(name: @branch.name)
        protected_branch.destroy if protected_branch

        present @branch, with: Entities::RepoObject, project: user_project
      end

      post ":id/repository/branches" do
        authorize_push_project
        result = CreateBranchService.new(user_project, current_user).
          execute(params[:branch_name], params[:ref])

        if result[:status] == :success
          present result[:branch],
                  with: Entities::RepoObject,
                  project: user_project
        else
          render_api_error!(result[:message], 400)
        end
      end

      delete ":id/repository/branches/:branch",
          requirements: { branch: /.*/ } do
        authorize_push_project
        result = DeleteBranchService.new(user_project, current_user).
          execute(params[:branch])

        if result[:status] == :success
          {
            branch_name: params[:branch]
          }
        else
          render_api_error!(result[:message], result[:return_code])
        end
      end
    end
  end
end
