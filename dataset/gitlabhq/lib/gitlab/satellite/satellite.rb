module Gitlab
  module Satellite
    autoload :DeleteFileAction, 'gitlab/satellite/files/delete_file_action'
    autoload :EditFileAction,   'gitlab/satellite/files/edit_file_action'
    autoload :FileAction,       'gitlab/satellite/files/file_action'
    autoload :NewFileAction,    'gitlab/satellite/files/new_file_action'

    class CheckoutFailed < StandardError; end
    class CommitFailed < StandardError; end
    class PushFailed < StandardError; end

    class Satellite
      include Gitlab::Popen

      PARKING_BRANCH = "__parking_branch"

      attr_accessor :project

      def initialize(project)
        @project = project
      end

      def log(message)
        Gitlab::Satellite::Logger.error(message)
      end

      def clear_and_update!
        project.ensure_satellite_exists

        @repo = nil
        clear_working_dir!
        delete_heads!
        remove_remotes!
        update_from_source!
      end

      def create
        output, status = popen(%W(git clone -- #{project.repository.path_to_repo} #{path}),
                               Gitlab.config.satellites.path)

        log("PID: #{project.id}: git clone #{project.repository.path_to_repo} #{path}")
        log("PID: #{project.id}: -> #{output}")

        if status.zero?
          true
        else
          log("Failed to create satellite for #{project.name_with_namespace}")
          false
        end
      end

      def exists?
        File.exists? path
      end

      def lock
        project.ensure_satellite_exists

        File.open(lock_file, "w+") do |f|
          begin
            f.flock File::LOCK_EX
            yield
          ensure
            f.flock File::LOCK_UN
          end
        end
      end

      def lock_file
        create_locks_dir unless File.exists?(lock_files_dir)
        File.join(lock_files_dir, "satellite_#{project.id}.lock")
      end

      def path
        File.join(Gitlab.config.satellites.path, project.path_with_namespace)
      end

      def repo
        project.ensure_satellite_exists

        @repo ||= Grit::Repo.new(path)
      end

      def destroy
        FileUtils.rm_rf(path)
      end

      private

      def clear_working_dir!
        repo.git.reset(hard: true)
        repo.git.clean(f: true, d: true, x: true)
      end

      def delete_heads!
        heads = repo.heads.map(&:name)

        repo.git.checkout(default_options({ B: true }), PARKING_BRANCH)

        heads.delete(PARKING_BRANCH)
        heads.each { |head| repo.git.branch(default_options({ D: true }), head) }
      end

      def remove_remotes!
        remotes = repo.git.remote.split(' ')
        remotes.delete('origin')
        remotes.each { |name| repo.git.remote(default_options,'rm', name)}
      end

      def update_from_source!
        repo.git.remote(default_options, 'set-url', :origin, project.repository.path_to_repo)
        repo.git.fetch(default_options, :origin)
      end

      def default_options(options = {})
        { raise: true, timeout: true }.merge(options)
      end

      def create_locks_dir
        FileUtils.mkdir_p(lock_files_dir)
      end

      def lock_files_dir
        @lock_files_dir ||= File.join(Gitlab.config.satellites.path, "tmp")
      end
    end
  end
end
