require_relative 'file_action'

module Gitlab
  module Satellite
    class NewFileAction < FileAction
      def commit!(content, commit_message, encoding, new_branch = nil)
        in_locked_and_timed_satellite do |repo|
          prepare_satellite!(repo)

          current_ref =
            if @project.empty_repo?
              Satellite::PARKING_BRANCH
            else
              repo.git.checkout({ raise: true, timeout: true, b: true }, ref, "origin/#{ref}")
              ref
            end

          file_path_in_satellite = File.join(repo.working_dir, file_path)
          dir_name_in_satellite = File.dirname(file_path_in_satellite)

          unless safe_path?(file_path_in_satellite)
            Gitlab::GitLogger.error("FileAction: Relative path not allowed")
            return false
          end

          FileUtils.mkdir_p(dir_name_in_satellite)

          write_file(file_path_in_satellite, content, encoding)

          repo.add(file_path_in_satellite)

          repo.git.commit(raise: true, timeout: true, a: true, m: commit_message)

          target_branch = if new_branch.present? && !@project.empty_repo?
                            "#{ref}:#{new_branch}"
                          else
                            "#{current_ref}:#{ref}"
                          end

          repo.git.push({ raise: true, timeout: true }, :origin, target_branch)

          true
        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end
    end
  end
end
