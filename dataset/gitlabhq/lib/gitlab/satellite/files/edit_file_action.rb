require_relative 'file_action'

module Gitlab
  module Satellite
    class EditFileAction < FileAction
      def commit!(content, commit_message, encoding, new_branch = nil)
        in_locked_and_timed_satellite do |repo|
          prepare_satellite!(repo)

          begin
            repo.git.checkout({ raise: true, timeout: true, b: true }, ref, "origin/#{ref}")
          rescue Grit::Git::CommandFailed => ex
            log_and_raise(CheckoutFailed, ex.message)
          end

          file_path_in_satellite = File.join(repo.working_dir, file_path)

          unless safe_path?(file_path_in_satellite)
            Gitlab::GitLogger.error("FileAction: Relative path not allowed")
            return false
          end

          write_file(file_path_in_satellite, content, encoding)

          begin
            repo.git.commit(raise: true, timeout: true, a: true, m: commit_message)
          rescue Grit::Git::CommandFailed => ex
            log_and_raise(CommitFailed, ex.message)
          end


          target_branch = new_branch.present? ? "#{ref}:#{new_branch}" : ref

          begin
            repo.git.push({ raise: true, timeout: true }, :origin, target_branch)
          rescue Grit::Git::CommandFailed => ex
            log_and_raise(PushFailed, ex.message)
          end

          true
        end
      end

      private

      def log_and_raise(errorClass, message)
        Gitlab::GitLogger.error(message)
        raise(errorClass, message)
      end
    end
  end
end
