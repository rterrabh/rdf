module API
  class ProjectHooks < Grape::API
    before { authenticate! }
    before { authorize_admin_project }

    resource :projects do
      get ":id/hooks" do
        @hooks = paginate user_project.hooks
        present @hooks, with: Entities::ProjectHook
      end

      get ":id/hooks/:hook_id" do
        @hook = user_project.hooks.find(params[:hook_id])
        present @hook, with: Entities::ProjectHook
      end


      post ":id/hooks" do
        required_attributes! [:url]
        attrs = attributes_for_keys [
          :url,
          :push_events,
          :issues_events,
          :merge_requests_events,
          :tag_push_events,
          :note_events
        ]
        @hook = user_project.hooks.new(attrs)

        if @hook.save
          present @hook, with: Entities::ProjectHook
        else
          if @hook.errors[:url].present?
            error!("Invalid url given", 422)
          end
          not_found!("Project hook #{@hook.errors.messages}")
        end
      end

      put ":id/hooks/:hook_id" do
        @hook = user_project.hooks.find(params[:hook_id])
        required_attributes! [:url]
        attrs = attributes_for_keys [
          :url,
          :push_events,
          :issues_events,
          :merge_requests_events,
          :tag_push_events,
          :note_events
        ]

        if @hook.update_attributes attrs
          present @hook, with: Entities::ProjectHook
        else
          if @hook.errors[:url].present?
            error!("Invalid url given", 422)
          end
          not_found!("Project hook #{@hook.errors.messages}")
        end
      end

      delete ":id/hooks/:hook_id" do
        required_attributes! [:hook_id]

        begin
          @hook = ProjectHook.find(params[:hook_id])
          @hook.destroy
        rescue
        end
      end
    end
  end
end
