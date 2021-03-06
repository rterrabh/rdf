load File.expand_path("../tasks/git.rake", __FILE__)

require 'capistrano/scm'

class Capistrano::Git < Capistrano::SCM

  def git(*args)
    args.unshift :git
    context.execute *args
  end

  module DefaultStrategy
    def test
      test! " [ -f #{repo_path}/HEAD ] "
    end

    def check
      git :'ls-remote --heads', repo_url
    end

    def clone
      git :clone, '--mirror', repo_url, repo_path
    end

    def update
      git :remote, :update
    end

    def release
      if tree = fetch(:repo_tree)
        tree = tree.slice %r#^/?(.*?)/?$#, 1
        components = tree.split('/').size
        git :archive, fetch(:branch), tree, "| tar -x --strip-components #{components} -f - -C", release_path
      else
        git :archive, fetch(:branch), '| tar -x -f - -C', release_path
      end
    end

    def fetch_revision
      context.capture(:git, "rev-list --max-count=1 --abbrev-commit #{fetch(:branch)}")
    end
  end
end
