module API
  class Internal < Grape::API
    before { authenticate_by_gitlab_shell_token! }

    namespace 'internal' do
      post "/allowed" do
        status 200

        actor = 
          if params[:key_id]
            Key.find_by(id: params[:key_id])
          elsif params[:user_id]
            User.find_by(id: params[:user_id])
          end

        project_path = params[:project]
        
        wiki = project_path.end_with?('.wiki')
        project_path.chomp!('.wiki') if wiki

        project = Project.find_with_namespace(project_path)

        access =
          if wiki
            Gitlab::GitAccessWiki.new(actor, project)
          else
            Gitlab::GitAccess.new(actor, project)
          end

        access.check(params[:action], params[:changes])
      end

      get "/discover" do
        key = Key.find(params[:key_id])
        present key.user, with: Entities::UserSafe
      end

      get "/check" do
        {
          api_version: API.version,
          gitlab_version: Gitlab::VERSION,
          gitlab_rev: Gitlab::REVISION,
        }
      end

      get "/broadcast_message" do
        if message = BroadcastMessage.current
          present message, with: Entities::BroadcastMessage
        else
          {}
        end
      end
    end
  end
end
