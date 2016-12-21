module MergeRequests
  # AutoMergeService class
  #
  # Do git merge in satellite and in case of success
  # mark merge request as merged and execute all hooks and notifications
  # Called when you do merge via GitLab UI
  class AutoMergeService < BaseMergeService
    def execute(merge_request, commit_message)
      merge_request.lock_mr

      if Gitlab::Satellite::MergeAction.new(current_user, merge_request).merge!(commit_message)
        merge_request.merge

        create_merge_event(merge_request, current_user)
        create_note(merge_request)
        notification_service.merge_mr(merge_request, current_user)
        execute_hooks(merge_request, 'merge')

        true
      else
        merge_request.unlock_mr
        false
      end
    rescue
      merge_request.unlock_mr if merge_request.locked?
      merge_request.mark_as_unmergeable
      false
    end
  end
end
