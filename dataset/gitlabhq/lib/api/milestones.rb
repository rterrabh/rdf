module API
  class Milestones < Grape::API
    before { authenticate! }

    resource :projects do
      get ":id/milestones" do
        authorize! :read_milestone, user_project

        present paginate(user_project.milestones), with: Entities::Milestone
      end

      get ":id/milestones/:milestone_id" do
        authorize! :read_milestone, user_project

        @milestone = user_project.milestones.find(params[:milestone_id])
        present @milestone, with: Entities::Milestone
      end

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

      get ":id/milestones/:milestone_id/issues" do
        authorize! :read_milestone, user_project

        @milestone = user_project.milestones.find(params[:milestone_id])
        present paginate(@milestone.issues), with: Entities::Issue
      end

    end
  end
end
