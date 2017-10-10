module API
  class MergeRequests < Grape::API
    before { authenticate! }

    resource :projects do
      helpers do
        def handle_merge_request_errors!(errors)
          if errors[:project_access].any?
            error!(errors[:project_access], 422)
          elsif errors[:branch_conflict].any?
            error!(errors[:branch_conflict], 422)
          elsif errors[:validate_fork].any?
            error!(errors[:validate_fork], 422)
          elsif errors[:validate_branches].any?
            conflict!(errors[:validate_branches])
          end

          render_api_error!(errors, 400)
        end
      end

      get ":id/merge_requests" do
        authorize! :read_merge_request, user_project
        merge_requests = user_project.merge_requests

        unless params[:iid].nil?
          merge_requests = filter_by_iid(merge_requests, params[:iid])
        end

        merge_requests =
          case params["state"]
          when "opened" then merge_requests.opened
          when "closed" then merge_requests.closed
          when "merged" then merge_requests.merged
          else merge_requests
          end

        merge_requests.reorder(issuable_order_by => issuable_sort)
        present paginate(merge_requests), with: Entities::MergeRequest
      end

      get ":id/merge_request/:merge_request_id" do
        merge_request = user_project.merge_requests.find(params[:merge_request_id])

        authorize! :read_merge_request, merge_request

        present merge_request, with: Entities::MergeRequest
      end

      get ':id/merge_request/:merge_request_id/changes' do
        merge_request = user_project.merge_requests.
          find(params[:merge_request_id])
        authorize! :read_merge_request, merge_request
        present merge_request, with: Entities::MergeRequestChanges
      end

      post ":id/merge_requests" do
        authorize! :create_merge_request, user_project
        required_attributes! [:source_branch, :target_branch, :title]
        attrs = attributes_for_keys [:source_branch, :target_branch, :assignee_id, :title, :target_project_id, :description]

        if (errors = validate_label_params(params)).any?
          render_api_error!({ labels: errors }, 400)
        end

        merge_request = ::MergeRequests::CreateService.new(user_project, current_user, attrs).execute

        if merge_request.valid?
          if params[:labels].present?
            merge_request.add_labels_by_names(params[:labels].split(","))
          end

          present merge_request, with: Entities::MergeRequest
        else
          handle_merge_request_errors! merge_request.errors
        end
      end

      put ":id/merge_request/:merge_request_id" do
        attrs = attributes_for_keys [:target_branch, :assignee_id, :title, :state_event, :description]
        merge_request = user_project.merge_requests.find(params[:merge_request_id])
        authorize! :update_merge_request, merge_request

        if params[:source_branch].present?
          render_api_error!('Source branch cannot be changed', 400)
        end

        if (errors = validate_label_params(params)).any?
          render_api_error!({ labels: errors }, 400)
        end

        merge_request = ::MergeRequests::UpdateService.new(user_project, current_user, attrs).execute(merge_request)

        if merge_request.valid?
          unless params[:labels].nil?
            merge_request.remove_labels
            merge_request.add_labels_by_names(params[:labels].split(","))
          end

          present merge_request, with: Entities::MergeRequest
        else
          handle_merge_request_errors! merge_request.errors
        end
      end

      put ":id/merge_request/:merge_request_id/merge" do
        merge_request = user_project.merge_requests.find(params[:merge_request_id])

        allowed = ::Gitlab::GitAccess.new(current_user, user_project).
          can_push_to_branch?(merge_request.target_branch)

        if allowed
          if merge_request.unchecked?
            merge_request.check_if_can_be_merged
          end

          if merge_request.open? && !merge_request.work_in_progress?
            if merge_request.can_be_merged?
              merge_request.automerge!(current_user, params[:merge_commit_message] || merge_request.merge_commit_message)
              present merge_request, with: Entities::MergeRequest
            else
              render_api_error!('Branch cannot be merged', 405)
            end
          else
            not_allowed!
          end
        else
          unauthorized!
        end
      end


      get ":id/merge_request/:merge_request_id/comments" do
        merge_request = user_project.merge_requests.find(params[:merge_request_id])

        authorize! :read_merge_request, merge_request

        present paginate(merge_request.notes.fresh), with: Entities::MRNote
      end

      post ":id/merge_request/:merge_request_id/comments" do
        required_attributes! [:note]

        merge_request = user_project.merge_requests.find(params[:merge_request_id])
        note = merge_request.notes.new(note: params[:note], project_id: user_project.id)
        note.author = current_user

        if note.save
          present note, with: Entities::MRNote
        else
          render_api_error!("Failed to save note #{note.errors.messages}", 400)
        end
      end
    end
  end
end
