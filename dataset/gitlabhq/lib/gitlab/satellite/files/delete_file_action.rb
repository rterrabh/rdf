require_relative 'file_action'

module Gitlab
  module Satellite
    class DeleteFileAction < FileAction
      def commit!(content, commit_message)
        in_locked_and_timed_satellite do |repo|
          prepare_satellite!(repo)

          repo.git.checkout({ raise: true, timeout: true, b: true }, ref, "origin/#{ref}")

          file_path_in_satellite = File.join(repo.working_dir, file_path)

          unless safe_path?(file_path_in_satellite)
            Gitlab::GitLogger.error("FileAction: Relative path not allowed")
            return false
          end

          File.delete(file_path_in_satellite)

          repo.remove(file_path_in_satellite)

          repo.git.commit(raise: true, timeout: true, a: true, m: commit_message)


          repo.git.push({ raise: true, timeout: true }, :origin, ref)

          true
        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end
    end
  end
end
