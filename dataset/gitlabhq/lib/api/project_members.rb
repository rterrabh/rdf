module API
  class ProjectMembers < Grape::API
    before { authenticate! }

    resource :projects do

      get ":id/members" do
        if params[:query].present?
          @members = paginate user_project.users.where("username LIKE ?", "%#{params[:query]}%")
        else
          @members = paginate user_project.users
        end
        present @members, with: Entities::ProjectMember, project: user_project
      end

      get ":id/members/:user_id" do
        @member = user_project.users.find params[:user_id]
        present @member, with: Entities::ProjectMember, project: user_project
      end

      post ":id/members" do
        authorize! :admin_project, user_project
        required_attributes! [:user_id, :access_level]

        project_member = user_project.project_member_by_id(params[:user_id])
        if project_member.nil?
          project_member = user_project.project_members.new(
            user_id: params[:user_id],
            access_level: params[:access_level]
          )
        end

        if project_member.save
          @member = project_member.user
          present @member, with: Entities::ProjectMember, project: user_project
        else
          handle_member_errors project_member.errors
        end
      end

      put ":id/members/:user_id" do
        authorize! :admin_project, user_project
        required_attributes! [:access_level]

        project_member = user_project.project_members.find_by(user_id: params[:user_id])
        not_found!("User can not be found") if project_member.nil?

        if project_member.update_attributes(access_level: params[:access_level])
          @member = project_member.user
          present @member, with: Entities::ProjectMember, project: user_project
        else
          handle_member_errors project_member.errors
        end
      end

      delete ":id/members/:user_id" do
        authorize! :admin_project, user_project
        project_member = user_project.project_members.find_by(user_id: params[:user_id])
        unless project_member.nil?
          project_member.destroy
        else
          { message: "Access revoked", id: params[:user_id].to_i }
        end
      end
    end
  end
end
