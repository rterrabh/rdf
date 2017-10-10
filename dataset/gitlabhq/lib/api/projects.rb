module API
  class Projects < Grape::API
    before { authenticate! }

    resource :projects do
      helpers do
        def map_public_to_visibility_level(attrs)
          publik = attrs.delete(:public)
          publik = parse_boolean(publik)
          attrs[:visibility_level] = Gitlab::VisibilityLevel::PUBLIC if !attrs[:visibility_level].present? && publik == true
          attrs
        end

        def filter_projects(projects)
          if params[:archived].present?
            projects = projects.where(archived: parse_boolean(params[:archived]))
          end

          if params[:search].present?
            projects = projects.search(params[:search])
          end

          if params[:ci_enabled_first].present?
            projects.includes(:gitlab_ci_service).
              reorder("services.active DESC, projects.#{project_order_by} #{project_sort}")
          else
            projects.reorder(project_order_by => project_sort)
          end
        end

        def project_order_by
          order_fields = %w(id name path created_at updated_at last_activity_at)

          if order_fields.include?(params['order_by'])
            params['order_by']
          else
            'created_at'
          end
        end

        def project_sort
          if params["sort"] == 'asc'
            :asc
          else
            :desc
          end
        end
      end

      get do
        @projects = current_user.authorized_projects
        @projects = filter_projects(@projects)
        @projects = paginate @projects
        present @projects, with: Entities::Project
      end

      get '/owned' do
        @projects = current_user.owned_projects
        @projects = filter_projects(@projects)
        @projects = paginate @projects
        present @projects, with: Entities::Project
      end

      get '/all' do
        authenticated_as_admin!
        @projects = Project.all
        @projects = filter_projects(@projects)
        @projects = paginate @projects
        present @projects, with: Entities::Project
      end

      get ":id" do
        present user_project, with: Entities::ProjectWithAccess, user: current_user
      end

      get ":id/events" do
        events = paginate user_project.events.recent
        present events, with: Entities::Event
      end

      post do
        required_attributes! [:name]
        attrs = attributes_for_keys [:name,
                                     :path,
                                     :description,
                                     :issues_enabled,
                                     :merge_requests_enabled,
                                     :wiki_enabled,
                                     :snippets_enabled,
                                     :namespace_id,
                                     :public,
                                     :visibility_level,
                                     :import_url]
        attrs = map_public_to_visibility_level(attrs)
        @project = ::Projects::CreateService.new(current_user, attrs).execute
        if @project.saved?
          present @project, with: Entities::Project
        else
          if @project.errors[:limit_reached].present?
            error!(@project.errors[:limit_reached], 403)
          end
          render_validation_error!(@project)
        end
      end

      post "user/:user_id" do
        authenticated_as_admin!
        user = User.find(params[:user_id])
        attrs = attributes_for_keys [:name,
                                     :description,
                                     :default_branch,
                                     :issues_enabled,
                                     :merge_requests_enabled,
                                     :wiki_enabled,
                                     :snippets_enabled,
                                     :public,
                                     :visibility_level,
                                     :import_url]
        attrs = map_public_to_visibility_level(attrs)
        @project = ::Projects::CreateService.new(user, attrs).execute
        if @project.saved?
          present @project, with: Entities::Project
        else
          render_validation_error!(@project)
        end
      end

      post 'fork/:id' do
        @forked_project =
          ::Projects::ForkService.new(user_project,
                                      current_user).execute
        if @forked_project.errors.any?
          conflict!(@forked_project.errors.messages)
        else
          present @forked_project, with: Entities::Project
        end
      end

      put ':id' do
        attrs = attributes_for_keys [:name,
                                     :path,
                                     :description,
                                     :default_branch,
                                     :issues_enabled,
                                     :merge_requests_enabled,
                                     :wiki_enabled,
                                     :snippets_enabled,
                                     :public,
                                     :visibility_level]
        attrs = map_public_to_visibility_level(attrs)
        authorize_admin_project
        authorize! :rename_project, user_project if attrs[:name].present?
        if attrs[:visibility_level].present?
          authorize! :change_visibility_level, user_project
        end

        ::Projects::UpdateService.new(user_project,
                                      current_user, attrs).execute

        if user_project.errors.any?
          render_validation_error!(user_project)
        else
          present user_project, with: Entities::Project
        end
      end

      delete ":id" do
        authorize! :remove_project, user_project
        ::Projects::DestroyService.new(user_project, current_user, {}).execute
      end

      post ":id/fork/:forked_from_id" do
        authenticated_as_admin!
        forked_from_project = find_project(params[:forked_from_id])
        unless forked_from_project.nil?
          if user_project.forked_from_project.nil?
            user_project.create_forked_project_link(forked_to_project_id: user_project.id, forked_from_project_id: forked_from_project.id)
          else
            render_api_error!("Project already forked", 409)
          end
        else
          not_found!("Source Project")
        end

      end

      delete ":id/fork" do
        authenticated_as_admin!
        unless user_project.forked_project_link.nil?
          user_project.forked_project_link.destroy
        end
      end
      get "/search/:query" do
        ids = current_user.authorized_projects.map(&:id)
        visibility_levels = [ Gitlab::VisibilityLevel::INTERNAL, Gitlab::VisibilityLevel::PUBLIC ]
        projects = Project.where("(id in (?) OR visibility_level in (?)) AND (name LIKE (?))", ids, visibility_levels, "%#{params[:query]}%")
        sort = params[:sort] == 'desc' ? 'desc' : 'asc'

        projects = case params["order_by"]
                   when 'id' then projects.order("id #{sort}")
                   when 'name' then projects.order("name #{sort}")
                   when 'created_at' then projects.order("created_at #{sort}")
                   when 'last_activity_at' then projects.order("last_activity_at #{sort}")
                   else projects
                   end

        present paginate(projects), with: Entities::Project
      end


      get ':id/users' do
        @users = User.where(id: user_project.team.users.map(&:id))
        @users = @users.search(params[:search]) if params[:search].present?
        @users = paginate @users
        present @users, with: Entities::UserBasic
      end
    end
  end
end
