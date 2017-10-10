module API
  class DeployKeys < Grape::API
    before { authenticate! }
    before { authorize_admin_project }

    resource :projects do
      get ":id/keys" do
        present user_project.deploy_keys, with: Entities::SSHKey
      end

      get ":id/keys/:key_id" do
        key = user_project.deploy_keys.find params[:key_id]
        present key, with: Entities::SSHKey
      end

      post ":id/keys" do
        attrs = attributes_for_keys [:title, :key]

        if attrs[:key].present?
          attrs[:key].strip!

          key = user_project.deploy_keys.find_by(key: attrs[:key])
          if key
            present key, with: Entities::SSHKey
            return
          end

          key = current_user.accessible_deploy_keys.find_by(key: attrs[:key])
          if key
            user_project.deploy_keys << key
            present key, with: Entities::SSHKey
            return
          end
        end

        key = DeployKey.new attrs

        if key.valid? && user_project.deploy_keys << key
          present key, with: Entities::SSHKey
        else
          render_validation_error!(key)
        end
      end

      delete ":id/keys/:key_id" do
        key = user_project.deploy_keys.find params[:key_id]
        key.destroy
      end
    end
  end
end
