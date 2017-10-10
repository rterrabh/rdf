module API
  class SystemHooks < Grape::API
    before do
      authenticate!
      authenticated_as_admin!
    end

    resource :hooks do
      get do
        @hooks = SystemHook.all
        present @hooks, with: Entities::Hook
      end

      post do
        attrs = attributes_for_keys [:url]
        required_attributes! [:url]
        @hook = SystemHook.new attrs
        if @hook.save
          present @hook, with: Entities::Hook
        else
          not_found!
        end
      end

      get ":id" do
        @hook = SystemHook.find(params[:id])
        data = {
          event_name: "project_create",
          name: "Ruby",
          path: "ruby",
          project_id: 1,
          owner_name: "Someone",
          owner_email: "example@gitlabhq.com"
        }
        @hook.execute(data, 'system_hooks')
        data
      end

      delete ":id" do
        begin
          @hook = SystemHook.find(params[:id])
          @hook.destroy
        rescue
        end
      end
    end
  end
end
