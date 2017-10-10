require 'mime/types'

module API
  class Commits < Grape::API
    before { authenticate! }
    before { authorize! :download_code, user_project }

    resource :projects do
      get ":id/repository/commits" do
        page = (params[:page] || 0).to_i
        per_page = (params[:per_page] || 20).to_i
        ref = params[:ref_name] || user_project.try(:default_branch) || 'master'

        commits = user_project.repository.commits(ref, nil, per_page, page * per_page)
        present commits, with: Entities::RepoCommit
      end

      get ":id/repository/commits/:sha" do
        sha = params[:sha]
        commit = user_project.commit(sha)
        not_found! "Commit" unless commit
        present commit, with: Entities::RepoCommitDetail
      end

      get ":id/repository/commits/:sha/diff" do
        sha = params[:sha]
        commit = user_project.commit(sha)
        not_found! "Commit" unless commit
        commit.diffs
      end

      get ':id/repository/commits/:sha/comments' do
        sha = params[:sha]
        commit = user_project.commit(sha)
        not_found! 'Commit' unless commit
        notes = Note.where(commit_id: commit.id).order(:created_at)
        present paginate(notes), with: Entities::CommitNote
      end

      post ':id/repository/commits/:sha/comments' do
        required_attributes! [:note]

        sha = params[:sha]
        commit = user_project.commit(sha)
        not_found! 'Commit' unless commit
        opts = {
          note: params[:note],
          noteable_type: 'Commit',
          commit_id: commit.id
        }

        if params[:path] && params[:line] && params[:line_type]
          commit.diffs.each do |diff|
            next unless diff.new_path == params[:path]
            lines = Gitlab::Diff::Parser.new.parse(diff.diff.lines.to_a)

            lines.each do |line|
              next unless line.new_pos == params[:line].to_i && line.type == params[:line_type]
              break opts[:line_code] = Gitlab::Diff::LineCode.generate(diff.new_path, line.new_pos, line.old_pos)
            end

            break if opts[:line_code]
          end
        end

        note = ::Notes::CreateService.new(user_project, current_user, opts).execute

        if note.save
          present note, with: Entities::CommitNote
        else
          render_api_error!("Failed to save note #{note.errors.messages}", 400)
        end
      end
    end
  end
end
