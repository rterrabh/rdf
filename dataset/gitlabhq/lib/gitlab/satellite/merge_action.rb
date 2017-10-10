module Gitlab
  module Satellite
    class MergeAction < Action
      attr_accessor :merge_request

      def initialize(user, merge_request)
        super user, merge_request.target_project
        @merge_request = merge_request
      end

      def can_be_merged?
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          merge_in_satellite!(merge_repo)
        end
      end

      def merge!(merge_commit_message = nil)
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          if merge_in_satellite!(merge_repo, merge_commit_message)
            merge_repo.git.push(default_options, :origin, merge_request.target_branch)

            if merge_request.remove_source_branch?
              merge_repo.git.push(default_options, :origin, ":#{merge_request.source_branch}")
              merge_request.source_project.repository.expire_branch_names
            end
            true
          end
        end
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      def diff_in_satellite
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          update_satellite_source_and_target!(merge_repo)

          common_commit = merge_repo.git.native(:merge_base, default_options, ["origin/#{merge_request.target_branch}", "source/#{merge_request.source_branch}"]).strip
          merge_repo.git.native(:diff, default_options, common_commit, "source/#{merge_request.source_branch}")
        end
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      def diffs_between_satellite
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          update_satellite_source_and_target!(merge_repo)
          if merge_request.for_fork?
            repository = Gitlab::Git::Repository.new(merge_repo.path)
            diffs = Gitlab::Git::Diff.between(
              repository,
              "source/#{merge_request.source_branch}",
              "origin/#{merge_request.target_branch}"
            )
          else
            raise "Attempt to determine diffs between for a non forked merge request in satellite MergeRequest.id:[#{merge_request.id}]"
          end

          return diffs
        end
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      def format_patch
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          update_satellite_source_and_target!(merge_repo)
          patch = merge_repo.git.format_patch(default_options({ stdout: true }), "origin/#{merge_request.target_branch}..source/#{merge_request.source_branch}")
        end
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      def commits_between
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite!(merge_repo)
          update_satellite_source_and_target!(merge_repo)
          if merge_request.for_fork?
            repository = Gitlab::Git::Repository.new(merge_repo.path)
            commits = Gitlab::Git::Commit.between(
              repository,
              "origin/#{merge_request.target_branch}",
              "source/#{merge_request.source_branch}"
            )
          else
            raise "Attempt to determine commits between for a non forked merge request in satellite MergeRequest.id:[#{merge_request.id}]"
          end

          return commits
        end
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      private
      def merge_in_satellite!(repo, message = nil)
        update_satellite_source_and_target!(repo)

        message ||= "Merge branch '#{merge_request.source_branch}' into '#{merge_request.target_branch}'"

        repo.git.merge(default_options({ no_ff: true }), "-m#{message}", "source/#{merge_request.source_branch}")
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end

      def update_satellite_source_and_target!(repo)
        repo.remote_add('source', merge_request.source_project.repository.path_to_repo)
        repo.remote_fetch('source')
        repo.git.checkout(default_options({ b: true }), merge_request.target_branch, "origin/#{merge_request.target_branch}")
      rescue Grit::Git::CommandFailed => ex
        handle_exception(ex)
      end
    end
  end
end
