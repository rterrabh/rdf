module API
  class Groups < Grape::API
    before { authenticate! }

    resource :groups do
      get do
        @groups = if current_user.admin
                    Group.all
                  else
                    current_user.groups
                  end

        @groups = @groups.search(params[:search]) if params[:search].present?
        @groups = paginate @groups
        present @groups, with: Entities::Group
      end

      post do
        authorize! :create_group, current_user
        required_attributes! [:name, :path]

        attrs = attributes_for_keys [:name, :path, :description]
        @group = Group.new(attrs)

        if @group.save
          @group.add_owner(current_user)
          present @group, with: Entities::Group
        else
          render_api_error!("Failed to save group #{@group.errors.messages}", 400)
        end
      end

      get ":id" do
        group = find_group(params[:id])
        present group, with: Entities::GroupDetail
      end

      delete ":id" do
        group = find_group(params[:id])
        authorize! :admin_group, group
        DestroyGroupService.new(group, current_user).execute
      end

      post ":id/projects/:project_id" do
        authenticated_as_admin!
        group = Group.find_by(id: params[:id])
        project = Project.find(params[:project_id])
        result = ::Projects::TransferService.new(project, current_user).execute(group)

        if result
          present group
        else
          render_api_error!("Failed to transfer project #{project.errors.messages}", 400)
        end
      end
    end
  end
end
