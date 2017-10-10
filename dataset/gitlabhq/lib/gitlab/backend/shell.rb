module Gitlab
  class Shell
    class AccessDenied < StandardError; end

    class KeyAdder < Struct.new(:io)
      def add_key(id, key)
        io.puts("#{id}\t#{key.strip}")
      end
    end

    class << self
      def version_required
        @version_required ||= File.read(Rails.root.
                                        join('GITLAB_SHELL_VERSION')).strip
      end
    end

    def add_repository(name)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path,
                                   'add-project', "#{name}.git"])
    end

    def import_repository(name, url)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'import-project',
                                   "#{name}.git", url, '240'])
    end

    def mv_repository(path, new_path)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'mv-project',
                                   "#{path}.git", "#{new_path}.git"])
    end

    def update_repository_head(path, branch)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'update-head',
                                   "#{path}.git", branch])
    end

    def fork_repository(path, fork_namespace)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'fork-project',
                                   "#{path}.git", fork_namespace])
    end

    def remove_repository(name)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path,
                                   'rm-project', "#{name}.git"])
    end

    def add_branch(path, branch_name, ref)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'create-branch',
                                   "#{path}.git", branch_name, ref])
    end

    def rm_branch(path, branch_name)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'rm-branch',
                                   "#{path}.git", branch_name])
    end

    def add_tag(path, tag_name, ref, message = nil)
      cmd = %W(#{gitlab_shell_path}/bin/gitlab-projects create-tag #{path}.git
      cmd << message unless message.nil? || message.empty?
      Gitlab::Utils.system_silent(cmd)
    end

    def rm_tag(path, tag_name)
      Gitlab::Utils.system_silent([gitlab_shell_projects_path, 'rm-tag',
                                   "#{path}.git", tag_name])
    end

    def add_key(key_id, key_content)
      Gitlab::Utils.system_silent([gitlab_shell_keys_path,
                                   'add-key', key_id, key_content])
    end

    def batch_add_keys(&block)
      IO.popen(%W(#{gitlab_shell_path}/bin/gitlab-keys batch-add-keys), 'w') do |io|
        block.call(KeyAdder.new(io))
      end
    end

    def remove_key(key_id, key_content)
      Gitlab::Utils.system_silent([gitlab_shell_keys_path,
                                   'rm-key', key_id, key_content])
    end

    def remove_all_keys
      Gitlab::Utils.system_silent([gitlab_shell_keys_path, 'clear'])
    end

    def add_namespace(name)
      FileUtils.mkdir(full_path(name), mode: 0770) unless exists?(name)
    end

    def rm_namespace(name)
      FileUtils.rm_r(full_path(name), force: true)
    end

    def mv_namespace(old_name, new_name)
      return false if exists?(new_name) || !exists?(old_name)

      FileUtils.mv(full_path(old_name), full_path(new_name))
    end

    def rm_satellites(path)
      raise ArgumentError.new("Path can't be blank") if path.blank?

      satellites_path = File.join(Gitlab.config.satellites.path, path)
      FileUtils.rm_r(satellites_path, force: true)
    end

    def url_to_repo(path)
      Gitlab.config.gitlab_shell.ssh_path_prefix + "#{path}.git"
    end

    def version
      gitlab_shell_version_file = "#{gitlab_shell_path}/VERSION"

      if File.readable?(gitlab_shell_version_file)
        File.read(gitlab_shell_version_file).chomp
      end
    end

    def exists?(dir_name)
      File.exists?(full_path(dir_name))
    end

    protected

    def gitlab_shell_path
      Gitlab.config.gitlab_shell.path
    end

    def gitlab_shell_user_home
      File.expand_path("~#{Gitlab.config.gitlab_shell.ssh_user}")
    end

    def repos_path
      Gitlab.config.gitlab_shell.repos_path
    end

    def full_path(dir_name)
      raise ArgumentError.new("Directory name can't be blank") if dir_name.blank?

      File.join(repos_path, dir_name)
    end

    def gitlab_shell_projects_path
      File.join(gitlab_shell_path, 'bin', 'gitlab-projects')
    end

    def gitlab_shell_keys_path
      File.join(gitlab_shell_path, 'bin', 'gitlab-keys')
    end
  end
end
