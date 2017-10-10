module MergeRequests
  class CloseService < MergeRequests::BaseService
    def execute(merge_request, commit = nil)
      merge_request.allow_broken = true

      if merge_request.close
        event_service.close_mr(merge_request, current_user)
        create_note(merge_request)
        notification_service.close_mr(merge_request, current_user)
        execute_hooks(merge_request, 'close')
      end

      merge_request
    end
  end
end
