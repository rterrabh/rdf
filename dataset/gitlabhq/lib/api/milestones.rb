module API
  # Milestones API
  class Milestones < Grape::API
    before { authenticate! }

    resource :projects do
      # Get a list of project milestones
      #
      # Parameters:
      #   id (required) - The ID of a project
      # Example Request:
      #   GET /projects/:id/milestones
      get ":id/milestones" do
        authorize! :read_milestone, user_project

        present paginate(user_project.milestones), with: Entities::Milestone
      end

      # Get a single project milestone
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   milestone_id (required) - The ID of a project milestone
      # Example Request:
      #   GET /projects/:id/milestones/:milestone_id
      get ":id/milestones/:milestone_id" do
        authorize! :read_milestone, user_project

        @milestone = user_project.milestones.find(params[:milestone_id])
        present @milestone, with: Entities::Milestone
      end

      # Create a new project milestone
      #
      # Parameters:
      #   id (required) - The ID of the project
      #   title (required) - The title of the milestone
      #   description (optional) - The description of the milestone
      #   due_date (optional) - The due date of the milestone
      # Example Request:
      #   POST /projects/:id/milestones
      post ":id/milestones" do
        authorize! :admin_milestone, user_project
        required_attributes! [:title]
        attrs = attributes_for_keys [:title, :description, :due_date]
        milestone = ::Milestones::CreateService.new(user_project, current_user, attrs).execute

        if milestone.valid?
          present milestone, with: Entities::Milestone
        else
          render_api_error!("Failed to create milestone #{milestone.errors.messages}", 400)
        end
      end

      # Update an existing project milestone
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   milestone_id (required) - The ID of a project milestone
      #   title (optional) - The title of a milestone
      #   description (optional) - The description of a milestone
      #   due_date (optional) - The due date of a milestone
      #   state_event (optional) - The state event of the milestone (close|activate)
      # Example Request:
      #   PUT /projects/:id/milestones/:milestone_id
      put ":id/milestones/:milestone_id" do
        authorize! :admin_milestone, user_project
        attrs = attributes_for_keys [:title, :description, :due_date, :state_event]
        milestone = user_project.milestones.find(params[:milestone_id])
        milestone = ::Milestones::UpdateService.new(user_project, current_user, attrs).execute(milestone)

        if milestone.valid?
          present milestone, with: Entities::Milestone
        else
          render_api_error!("Failed to update milestone #{milestone.errors.messages}", 400)
        end
      end

      # Get all issues for a single project milestone
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   milestone_id (required) - The ID of a project milestone
      # Example Request:
      #   GET /projects/:id/milestones/:milestone_id/issues
      get ":id/milestones/:milestone_id/issues" do
        authorize! :read_milestone, user_project

        @milestone = user_project.milestones.find(params[:milestone_id])
        present paginate(@milestone.issues), with: Entities::Issue
      end

    end
  end
end
