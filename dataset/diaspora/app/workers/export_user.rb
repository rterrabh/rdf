

module Workers
  class ExportUser < Base
    sidekiq_options queue: :export

    def perform(user_id)
      @user = User.find(user_id)
      @user.perform_export!

      if @user.reload.export.present?
        ExportMailer.export_complete_for(@user).deliver_now
      else
        ExportMailer.export_failure_for(@user).deliver_now
      end
    end
  end
end
