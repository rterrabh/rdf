module API
  class Services < Grape::API
    before { authenticate! }
    before { authorize_admin_project }

    resource :projects do
      put ":id/services/gitlab-ci" do
        required_attributes! [:token, :project_url]
        attrs = attributes_for_keys [:token, :project_url]
        user_project.build_missing_services

        if user_project.gitlab_ci_service.update_attributes(attrs.merge(active: true))
          true
        else
          not_found!
        end
      end

      delete ":id/services/gitlab-ci" do
        if user_project.gitlab_ci_service
          user_project.gitlab_ci_service.update_attributes(
            active: false,
            token: nil,
            project_url: nil
          )
        end
      end

      put ':id/services/hipchat' do
        required_attributes! [:token, :room]
        attrs = attributes_for_keys [:token, :room]
        user_project.build_missing_services

        if user_project.hipchat_service.update_attributes(
            attrs.merge(active: true))
          true
        else
          not_found!
        end
      end

      delete ':id/services/hipchat' do
        if user_project.hipchat_service
          user_project.hipchat_service.update_attributes(
            active: false,
            token: nil,
            room: nil
          )
        end
      end
    end
  end
end
