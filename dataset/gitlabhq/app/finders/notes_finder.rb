class NotesFinder
  FETCH_OVERLAP = 5.seconds

  def execute(project, current_user, params)
    target_type = params[:target_type]
    target_id   = params[:target_id]
    last_fetched_at = Time.at(params.fetch(:last_fetched_at, 0).to_i)

    notes =
      case target_type
      when "commit"
        project.notes.for_commit_id(target_id).not_inline
      when "issue"
        project.issues.find(target_id).notes.inc_author
      when "merge_request"
        project.merge_requests.find(target_id).mr_and_commit_notes.inc_author
      when "snippet", "project_snippet"
        project.snippets.find(target_id).notes
      else
        raise 'invalid target_type'
      end

    notes.where('updated_at > ?', last_fetched_at - FETCH_OVERLAP).fresh
  end
end
