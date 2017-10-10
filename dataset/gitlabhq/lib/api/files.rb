module API
  class Files < Grape::API
    before { authenticate! }

    resource :projects do
      get ":id/repository/files" do
        authorize! :download_code, user_project

        required_attributes! [:file_path, :ref]
        attrs = attributes_for_keys [:file_path, :ref]
        ref = attrs.delete(:ref)
        file_path = attrs.delete(:file_path)

        commit = user_project.commit(ref)
        not_found! 'Commit' unless commit

        blob = user_project.repository.blob_at(commit.sha, file_path)

        if blob
          status(200)

          {
            file_name: blob.name,
            file_path: blob.path,
            size: blob.size,
            encoding: "base64",
            content: Base64.strict_encode64(blob.data),
            ref: ref,
            blob_id: blob.id,
            commit_id: commit.id,
          }
        else
          not_found! 'File'
        end
      end

      post ":id/repository/files" do
        authorize! :push_code, user_project

        required_attributes! [:file_path, :branch_name, :content, :commit_message]
        attrs = attributes_for_keys [:file_path, :branch_name, :content, :commit_message, :encoding]
        branch_name = attrs.delete(:branch_name)
        file_path = attrs.delete(:file_path)
        result = ::Files::CreateService.new(user_project, current_user, attrs, branch_name, file_path).execute

        if result[:status] == :success
          status(201)

          {
            file_path: file_path,
            branch_name: branch_name
          }
        else
          render_api_error!(result[:message], 400)
        end
      end

      put ":id/repository/files" do
        authorize! :push_code, user_project

        required_attributes! [:file_path, :branch_name, :content, :commit_message]
        attrs = attributes_for_keys [:file_path, :branch_name, :content, :commit_message, :encoding]
        branch_name = attrs.delete(:branch_name)
        file_path = attrs.delete(:file_path)
        result = ::Files::UpdateService.new(user_project, current_user, attrs, branch_name, file_path).execute

        if result[:status] == :success
          status(200)

          {
            file_path: file_path,
            branch_name: branch_name
          }
        else
          http_status = result[:http_status] || 400
          render_api_error!(result[:message], http_status)
        end
      end

      delete ":id/repository/files" do
        authorize! :push_code, user_project

        required_attributes! [:file_path, :branch_name, :commit_message]
        attrs = attributes_for_keys [:file_path, :branch_name, :commit_message]
        branch_name = attrs.delete(:branch_name)
        file_path = attrs.delete(:file_path)
        result = ::Files::DeleteService.new(user_project, current_user, attrs, branch_name, file_path).execute

        if result[:status] == :success
          status(200)

          {
            file_path: file_path,
            branch_name: branch_name
          }
        else
          render_api_error!(result[:message], 400)
        end
      end
    end
  end
end
