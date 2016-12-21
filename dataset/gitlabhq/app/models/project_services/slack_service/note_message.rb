class SlackService
  class NoteMessage < BaseMessage
    attr_reader :message
    attr_reader :user_name
    attr_reader :project_name
    attr_reader :project_link
    attr_reader :note
    attr_reader :note_url
    attr_reader :title

    def initialize(params)
      params = HashWithIndifferentAccess.new(params)
      @user_name = params[:user][:name]
      @project_name = params[:project_name]
      @project_url = params[:project_url]

      obj_attr = params[:object_attributes]
      obj_attr = HashWithIndifferentAccess.new(obj_attr)
      @note = obj_attr[:note]
      @note_url = obj_attr[:url]
      noteable_type = obj_attr[:noteable_type]

      case noteable_type
      when "Commit"
        create_commit_note(HashWithIndifferentAccess.new(params[:commit]))
      when "Issue"
        create_issue_note(HashWithIndifferentAccess.new(params[:issue]))
      when "MergeRequest"
        create_merge_note(HashWithIndifferentAccess.new(params[:merge_request]))
      when "Snippet"
        create_snippet_note(HashWithIndifferentAccess.new(params[:snippet]))
      end
    end

    def attachments
      description_message
    end

    private

    def format_title(title)
      title.lines.first.chomp
    end

    def create_commit_note(commit)
      commit_sha = commit[:id]
      commit_sha = Commit.truncate_sha(commit_sha)
      commit_link = "[commit #{commit_sha}](#{@note_url})"
      title = format_title(commit[:message])
      @message = "#{@user_name} commented on #{commit_link} in #{project_link}: *#{title}*"
    end

    def create_issue_note(issue)
      issue_iid = issue[:iid]
      note_link = "[issue ##{issue_iid}](#{@note_url})"
      title = format_title(issue[:title])
      @message = "#{@user_name} commented on #{note_link} in #{project_link}: *#{title}*"
    end

    def create_merge_note(merge_request)
      merge_request_id = merge_request[:iid]
      merge_request_link = "[merge request ##{merge_request_id}](#{@note_url})"
      title = format_title(merge_request[:title])
      @message = "#{@user_name} commented on #{merge_request_link} in #{project_link}: *#{title}*"
    end

    def create_snippet_note(snippet)
      snippet_id = snippet[:id]
      snippet_link = "[snippet ##{snippet_id}](#{@note_url})"
      title = format_title(snippet[:title])
      @message = "#{@user_name} commented on #{snippet_link} in #{project_link}: *#{title}*"
    end

    def description_message
      [{ text: format(@note), color: attachment_color }]
    end

    def project_link
      "[#{@project_name}](#{@project_url})"
    end
  end
end
