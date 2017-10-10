module API
  class Notes < Grape::API
    before { authenticate! }

    NOTEABLE_TYPES = [Issue, MergeRequest, Snippet]

    resource :projects do
      NOTEABLE_TYPES.each do |noteable_type|
        noteables_str = noteable_type.to_s.underscore.pluralize
        noteable_id_str = "#{noteable_type.to_s.underscore}_id"

        get ":id/#{noteables_str}/:#{noteable_id_str}/notes" do
          #nodyna <send-496> <SD MODERATE (change-prone variables)>
          @noteable = user_project.send(:"#{noteables_str}").find(params[:"#{noteable_id_str}"])
          present paginate(@noteable.notes), with: Entities::Note
        end

        get ":id/#{noteables_str}/:#{noteable_id_str}/notes/:note_id" do
          #nodyna <send-497> <SD MODERATE (change-prone variables)>
          @noteable = user_project.send(:"#{noteables_str}").find(params[:"#{noteable_id_str}"])
          @note = @noteable.notes.find(params[:note_id])
          present @note, with: Entities::Note
        end

        post ":id/#{noteables_str}/:#{noteable_id_str}/notes" do
          required_attributes! [:body]

          opts = {
           note: params[:body],
           noteable_type: noteables_str.classify,
           noteable_id: params[noteable_id_str]
          }

          @note = ::Notes::CreateService.new(user_project, current_user, opts).execute

          if @note.valid?
            present @note, with: Entities::Note
          else
            not_found!("Note #{@note.errors.messages}")
          end
        end

        put ":id/#{noteables_str}/:#{noteable_id_str}/notes/:note_id" do
          required_attributes! [:body]

          note = user_project.notes.find(params[:note_id])

          authorize! :admin_note, note

          opts = {
            note: params[:body]
          }

          @note = ::Notes::UpdateService.new(user_project, current_user, opts).execute(note)

          if @note.valid?
            present @note, with: Entities::Note
          else
            render_api_error!("Failed to save note #{note.errors.messages}", 400)
          end
        end

      end
    end
  end
end
