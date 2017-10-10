module Backup
  class Uploads
    attr_reader :app_uploads_dir, :backup_uploads_dir, :backup_dir

    def initialize
      @app_uploads_dir = File.realpath(Rails.root.join('public', 'uploads'))
      @backup_dir = Gitlab.config.backup.path
      @backup_uploads_dir = File.join(Gitlab.config.backup.path, 'uploads')
    end

    def dump
      FileUtils.rm_rf(backup_uploads_dir)
      FileUtils.mkdir_p(Gitlab.config.backup.path)
      FileUtils.mkdir(backup_uploads_dir, mode: 0700)
      FileUtils.cp_r(app_uploads_dir, backup_dir)
    end

    def restore
      backup_existing_uploads_dir

      FileUtils.cp_r(backup_uploads_dir, app_uploads_dir)
    end

    def backup_existing_uploads_dir
      timestamped_uploads_path = File.join(app_uploads_dir, '..', "uploads.#{Time.now.to_i}")
      if File.exists?(app_uploads_dir)
        FileUtils.mv(app_uploads_dir, File.expand_path(timestamped_uploads_path))
      end
    end
  end
end
