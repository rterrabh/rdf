

module Workers
  class ExportPhotos < Base
    sidekiq_options queue: :export

    def perform(user_id)
      @user = User.find(user_id)
      @user.perform_export_photos!

      if @user.reload.exported_photos_file.present?
        ExportMailer.export_photos_complete_for(@user)
      else
        ExportMailer.export_photos_failure_for(@user)
      end
    end
  end
end
