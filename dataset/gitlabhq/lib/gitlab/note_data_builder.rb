module Gitlab
  class NoteDataBuilder
    class << self
      def build(note, user)
        project = note.project
        data = build_base_data(project, user, note)

        if note.for_commit?
          data[:commit] = build_data_for_commit(project, user, note)
        elsif note.for_issue?
          data[:issue] = note.noteable.hook_attrs
        elsif note.for_merge_request?
          data[:merge_request] = note.noteable.hook_attrs
        elsif note.for_project_snippet?
          data[:snippet] = note.noteable.hook_attrs
        end

        data
      end

      def build_base_data(project, user, note)
        base_data = {
          object_kind: "note",
          user: user.hook_attrs,
          project_id: project.id,
          repository: {
            name: project.name,
            url: project.url_to_repo,
            description: project.description,
            homepage: project.web_url,
          },
          object_attributes: note.hook_attrs
        }

        base_data[:object_attributes][:url] =
             Gitlab::UrlBuilder.new(:note).build(note.id)
        base_data
      end

      def build_data_for_commit(project, user, note)
        commit = project.commit(note.commit_id)
        commit.hook_attrs
      end
    end
  end
end
