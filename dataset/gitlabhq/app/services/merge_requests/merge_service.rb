module MergeRequests
  class MergeService < BaseMergeService
    def execute(merge_request, commit_message)
      merge_request.merge

      create_merge_event(merge_request, current_user)
      create_note(merge_request)
      notification_service.merge_mr(merge_request, current_user)
      execute_hooks(merge_request, 'merge')

      true
    rescue
      false
    end
  end
end
