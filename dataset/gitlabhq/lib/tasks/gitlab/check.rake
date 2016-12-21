namespace :gitlab do
  desc "GitLab | Check the configuration of GitLab and its environment"
  task check: %w{gitlab:gitlab_shell:check
                 gitlab:sidekiq:check
                 gitlab:ldap:check
                 gitlab:app:check}



  namespace :app do
    desc "GitLab | Check the configuration of the GitLab Rails app"
    task check: :environment  do
      warn_user_is_not_gitlab
      start_checking "GitLab"

      check_git_config
      check_database_config_exists
      check_database_is_not_sqlite
      check_migrations_are_up
      check_orphaned_group_members
      check_gitlab_config_exists
      check_gitlab_config_not_outdated
      check_log_writable
      check_tmp_writable
      check_init_script_exists
      check_init_script_up_to_date
      check_projects_have_namespace
      check_satellites_exist
      check_redis_version
      check_ruby_version
      check_git_version
      check_active_users

      finished_checking "GitLab"
    end


    # Checks
    ########################

    def check_git_config
      print "Git configured with autocrlf=input? ... "

      options = {
        "core.autocrlf" => "input"
      }

      correct_options = options.map do |name, value|
        run(%W(#{Gitlab.config.git.bin_path} config --global --get #{name})).try(:squish) == value
      end

      if correct_options.all?
        puts "yes".green
      else
        print "Trying to fix Git error automatically. ..."

        if auto_fix_git_config(options)
          puts "Success".green
        else
          puts "Failed".red
          try_fixing_it(
            sudo_gitlab("\"#{Gitlab.config.git.bin_path}\" config --global core.autocrlf \"#{options["core.autocrlf"]}\"")
          )
          for_more_information(
            see_installation_guide_section "GitLab"
          )
       end
      end
    end

    def check_database_config_exists
      print "Database config exists? ... "

      database_config_file = Rails.root.join("config", "database.yml")

      if File.exists?(database_config_file)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "Copy config/database.yml.<your db> to config/database.yml",
          "Check that the information in config/database.yml is correct"
        )
        for_more_information(
          see_database_guide,
          "http://guides.rubyonrails.org/getting_started.html#configuring-a-database"
        )
        fix_and_rerun
      end
    end

    def check_database_is_not_sqlite
      print "Database is SQLite ... "

      database_config_file = Rails.root.join("config", "database.yml")

      unless File.read(database_config_file) =~ /adapter:\s+sqlite/
        puts "no".green
      else
        puts "yes".red
        puts "Please fix this by removing the SQLite entry from the database.yml".blue
        for_more_information(
          "https://github.com/gitlabhq/gitlabhq/wiki/Migrate-from-SQLite-to-MySQL",
          see_database_guide
        )
        fix_and_rerun
      end
    end

    def check_gitlab_config_exists
      print "GitLab config exists? ... "

      gitlab_config_file = Rails.root.join("config", "gitlab.yml")

      if File.exists?(gitlab_config_file)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "Copy config/gitlab.yml.example to config/gitlab.yml",
          "Update config/gitlab.yml to match your setup"
        )
        for_more_information(
          see_installation_guide_section "GitLab"
        )
        fix_and_rerun
      end
    end

    def check_gitlab_config_not_outdated
      print "GitLab config outdated? ... "

      gitlab_config_file = Rails.root.join("config", "gitlab.yml")
      unless File.exists?(gitlab_config_file)
        puts "can't check because of previous errors".magenta
      end

      # omniauth or ldap could have been deleted from the file
      unless Gitlab.config['git_host']
        puts "no".green
      else
        puts "yes".red
        try_fixing_it(
          "Backup your config/gitlab.yml",
          "Copy config/gitlab.yml.example to config/gitlab.yml",
          "Update config/gitlab.yml to match your setup"
        )
        for_more_information(
          see_installation_guide_section "GitLab"
        )
        fix_and_rerun
      end
    end

    def check_init_script_exists
      print "Init script exists? ... "

      if omnibus_gitlab?
        puts 'skipped (omnibus-gitlab has no init script)'.magenta
        return
      end

      script_path = "/etc/init.d/gitlab"

      if File.exists?(script_path)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "Install the init script"
        )
        for_more_information(
          see_installation_guide_section "Install Init Script"
        )
        fix_and_rerun
      end
    end

    def check_init_script_up_to_date
      print "Init script up-to-date? ... "

      if omnibus_gitlab?
        puts 'skipped (omnibus-gitlab has no init script)'.magenta
        return
      end

      recipe_path = Rails.root.join("lib/support/init.d/", "gitlab")
      script_path = "/etc/init.d/gitlab"

      unless File.exists?(script_path)
        puts "can't check because of previous errors".magenta
        return
      end

      recipe_content = File.read(recipe_path)
      script_content = File.read(script_path)

      if recipe_content == script_content
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "Redownload the init script"
        )
        for_more_information(
          see_installation_guide_section "Install Init Script"
        )
        fix_and_rerun
      end
    end

    def check_migrations_are_up
      print "All migrations up? ... "

      migration_status, _ = Gitlab::Popen.popen(%W(bundle exec rake db:migrate:status))

      unless migration_status =~ /down\s+\d{14}/
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          sudo_gitlab("bundle exec rake db:migrate RAILS_ENV=production")
        )
        fix_and_rerun
      end
    end

    def check_orphaned_group_members
      print "Database contains orphaned GroupMembers? ... "
      if GroupMember.where("user_id not in (select id from users)").count > 0
        puts "yes".red
        try_fixing_it(
          "You can delete the orphaned records using something along the lines of:",
          sudo_gitlab("bundle exec rails runner -e production 'GroupMember.where(\"user_id NOT IN (SELECT id FROM users)\").delete_all'")
        )
      else
        puts "no".green
      end
    end

    def check_satellites_exist
      print "Projects have satellites? ... "

      unless Project.count > 0
        puts "can't check, you have no projects".magenta
        return
      end
      puts ""

      Project.find_each(batch_size: 100) do |project|
        print sanitized_message(project)

        if project.satellite.exists?
          puts "yes".green
        elsif project.empty_repo?
          puts "can't create, repository is empty".magenta
        else
          puts "no".red
          try_fixing_it(
            sudo_gitlab("bundle exec rake gitlab:satellites:create RAILS_ENV=production"),
            "If necessary, remove the tmp/repo_satellites directory ...",
            "... and rerun the above command"
          )
          for_more_information(
            "doc/raketasks/maintenance.md "
          )
          fix_and_rerun
        end
      end
    end

    def check_log_writable
      print "Log directory writable? ... "

      log_path = Rails.root.join("log")

      if File.writable?(log_path)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "sudo chown -R gitlab #{log_path}",
          "sudo chmod -R u+rwX #{log_path}"
        )
        for_more_information(
          see_installation_guide_section "GitLab"
        )
        fix_and_rerun
      end
    end

    def check_tmp_writable
      print "Tmp directory writable? ... "

      tmp_path = Rails.root.join("tmp")

      if File.writable?(tmp_path)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "sudo chown -R gitlab #{tmp_path}",
          "sudo chmod -R u+rwX #{tmp_path}"
        )
        for_more_information(
          see_installation_guide_section "GitLab"
        )
        fix_and_rerun
      end
    end

    def check_redis_version
      print "Redis version >= 2.0.0? ... "

      redis_version = run(%W(redis-cli --version))
      if redis_version.try(:match, /redis-cli 2.\d.\d/) || redis_version.try(:match, /redis-cli 3.\d.\d/)
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "Update your redis server to a version >= 2.0.0"
        )
        for_more_information(
          "gitlab-public-wiki/wiki/Trouble-Shooting-Guide in section sidekiq"
        )
        fix_and_rerun
      end
    end
  end

  namespace :gitlab_shell do
    desc "GitLab | Check the configuration of GitLab Shell"
    task check: :environment  do
      warn_user_is_not_gitlab
      start_checking "GitLab Shell"

      check_gitlab_shell
      check_repo_base_exists
      check_repo_base_is_not_symlink
      check_repo_base_user_and_group
      check_repo_base_permissions
      check_satellites_permissions
      check_repos_hooks_directory_is_link
      check_gitlab_shell_self_test

      finished_checking "GitLab Shell"
    end


    # Checks
    ########################

    def check_repo_base_exists
      print "Repo base directory exists? ... "

      repo_base_path = Gitlab.config.gitlab_shell.repos_path

      if File.exists?(repo_base_path)
        puts "yes".green
      else
        puts "no".red
        puts "#{repo_base_path} is missing".red
        try_fixing_it(
          "This should have been created when setting up GitLab Shell.",
          "Make sure it's set correctly in config/gitlab.yml",
          "Make sure GitLab Shell is installed correctly."
        )
        for_more_information(
          see_installation_guide_section "GitLab Shell"
        )
        fix_and_rerun
      end
    end

    def check_repo_base_is_not_symlink
      print "Repo base directory is a symlink? ... "

      repo_base_path = Gitlab.config.gitlab_shell.repos_path
      unless File.exists?(repo_base_path)
        puts "can't check because of previous errors".magenta
        return
      end

      unless File.symlink?(repo_base_path)
        puts "no".green
      else
        puts "yes".red
        try_fixing_it(
          "Make sure it's set to the real directory in config/gitlab.yml"
        )
        fix_and_rerun
      end
    end

    def check_repo_base_permissions
      print "Repo base access is drwxrws---? ... "

      repo_base_path = Gitlab.config.gitlab_shell.repos_path
      unless File.exists?(repo_base_path)
        puts "can't check because of previous errors".magenta
        return
      end

      if File.stat(repo_base_path).mode.to_s(8).ends_with?("2770")
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "sudo chmod -R ug+rwX,o-rwx #{repo_base_path}",
          "sudo chmod -R ug-s #{repo_base_path}",
          "find #{repo_base_path} -type d -print0 | sudo xargs -0 chmod g+s"
        )
        for_more_information(
          see_installation_guide_section "GitLab Shell"
        )
        fix_and_rerun
      end
    end

    def check_satellites_permissions
      print "Satellites access is drwxr-x---? ... "

      satellites_path = Gitlab.config.satellites.path
      unless File.exists?(satellites_path)
        puts "can't check because of previous errors".magenta
        return
      end

      if File.stat(satellites_path).mode.to_s(8).ends_with?("0750")
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          "sudo chmod u+rwx,g=rx,o-rwx #{satellites_path}",
        )
        for_more_information(
          see_installation_guide_section "GitLab"
        )
        fix_and_rerun
      end
    end

    def check_repo_base_user_and_group
      gitlab_shell_ssh_user = Gitlab.config.gitlab_shell.ssh_user
      gitlab_shell_owner_group = Gitlab.config.gitlab_shell.owner_group
      print "Repo base owned by #{gitlab_shell_ssh_user}:#{gitlab_shell_owner_group}? ... "

      repo_base_path = Gitlab.config.gitlab_shell.repos_path
      unless File.exists?(repo_base_path)
        puts "can't check because of previous errors".magenta
        return
      end

      uid = uid_for(gitlab_shell_ssh_user)
      gid = gid_for(gitlab_shell_owner_group)
      if File.stat(repo_base_path).uid == uid && File.stat(repo_base_path).gid == gid
        puts "yes".green
      else
        puts "no".red
        puts "  User id for #{gitlab_shell_ssh_user}: #{uid}. Groupd id for #{gitlab_shell_owner_group}: #{gid}".blue
        try_fixing_it(
          "sudo chown -R #{gitlab_shell_ssh_user}:#{gitlab_shell_owner_group} #{repo_base_path}"
        )
        for_more_information(
          see_installation_guide_section "GitLab Shell"
        )
        fix_and_rerun
      end
    end

    def check_repos_hooks_directory_is_link
      print "hooks directories in repos are links: ... "

      gitlab_shell_hooks_path = Gitlab.config.gitlab_shell.hooks_path

      unless Project.count > 0
        puts "can't check, you have no projects".magenta
        return
      end
      puts ""

      Project.find_each(batch_size: 100) do |project|
        print sanitized_message(project)
        project_hook_directory = File.join(project.repository.path_to_repo, "hooks")

        if project.empty_repo?
          puts "repository is empty".magenta
        elsif File.directory?(project_hook_directory) && File.directory?(gitlab_shell_hooks_path) &&
            (File.realpath(project_hook_directory) == File.realpath(gitlab_shell_hooks_path))
          puts 'ok'.green
        else
          puts "wrong or missing hooks".red
          try_fixing_it(
            sudo_gitlab("#{gitlab_shell_path}/bin/create-hooks"),
            'Check the hooks_path in config/gitlab.yml',
            'Check your gitlab-shell installation'
          )
          for_more_information(
            see_installation_guide_section "GitLab Shell"
          )
          fix_and_rerun
        end

      end
    end

    def check_gitlab_shell_self_test
      gitlab_shell_repo_base = gitlab_shell_path
      check_cmd = File.expand_path('bin/check', gitlab_shell_repo_base)
      puts "Running #{check_cmd}"
      if system(check_cmd, chdir: gitlab_shell_repo_base)
        puts 'gitlab-shell self-check successful'.green
      else
        puts 'gitlab-shell self-check failed'.red
        try_fixing_it(
          'Make sure GitLab is running;',
          'Check the gitlab-shell configuration file:',
          sudo_gitlab("editor #{File.expand_path('config.yml', gitlab_shell_repo_base)}")
        )
        fix_and_rerun
      end
    end

    def check_projects_have_namespace
      print "projects have namespace: ... "

      unless Project.count > 0
        puts "can't check, you have no projects".magenta
        return
      end
      puts ""

      Project.find_each(batch_size: 100) do |project|
        print sanitized_message(project)

        if project.namespace
          puts "yes".green
        else
          puts "no".red
          try_fixing_it(
            "Migrate global projects"
          )
          for_more_information(
            "doc/update/5.4-to-6.0.md in section \"#global-projects\""
          )
          fix_and_rerun
        end
      end
    end

    # Helper methods
    ########################

    def gitlab_shell_path
      Gitlab.config.gitlab_shell.path
    end

    def gitlab_shell_version
      Gitlab::Shell.new.version
    end

    def gitlab_shell_major_version
      Gitlab::Shell.version_required.split('.')[0].to_i
    end

    def gitlab_shell_minor_version
      Gitlab::Shell.version_required.split('.')[1].to_i
    end

    def gitlab_shell_patch_version
      Gitlab::Shell.version_required.split('.')[2].to_i
    end
  end



  namespace :sidekiq do
    desc "GitLab | Check the configuration of Sidekiq"
    task check: :environment  do
      warn_user_is_not_gitlab
      start_checking "Sidekiq"

      check_sidekiq_running
      only_one_sidekiq_running

      finished_checking "Sidekiq"
    end


    # Checks
    ########################

    def check_sidekiq_running
      print "Running? ... "

      if sidekiq_process_count > 0
        puts "yes".green
      else
        puts "no".red
        try_fixing_it(
          sudo_gitlab("RAILS_ENV=production bin/background_jobs start")
        )
        for_more_information(
          see_installation_guide_section("Install Init Script"),
          "see log/sidekiq.log for possible errors"
        )
        fix_and_rerun
      end
    end

    def only_one_sidekiq_running
      process_count = sidekiq_process_count
      return if process_count.zero?

      print 'Number of Sidekiq processes ... '
      if process_count == 1
        puts '1'.green
      else
        puts "#{process_count}".red
        try_fixing_it(
          'sudo service gitlab stop',
          "sudo pkill -u #{gitlab_user} -f sidekiq",
          "sleep 10 && sudo pkill -9 -u #{gitlab_user} -f sidekiq",
          'sudo service gitlab start'
        )
        fix_and_rerun
      end
    end

    def sidekiq_process_count
      ps_ux, _ = Gitlab::Popen.popen(%W(ps ux))
      ps_ux.scan(/sidekiq \d+\.\d+\.\d+/).count
    end
  end

  namespace :ldap do
    task :check, [:limit] => :environment do |t, args|
      # Only show up to 100 results because LDAP directories can be very big.
      # This setting only affects the `rake gitlab:check` script.
      args.with_defaults(limit: 100)
      warn_user_is_not_gitlab
      start_checking "LDAP"

      if Gitlab::LDAP::Config.enabled?
        print_users(args.limit)
      else
        puts 'LDAP is disabled in config/gitlab.yml'
      end

      finished_checking "LDAP"
    end

    def print_users(limit)
      puts "LDAP users with access to your GitLab server (only showing the first #{limit} results)"

      servers = Gitlab::LDAP::Config.providers

      servers.each do |server|
        puts "Server: #{server}"
        Gitlab::LDAP::Adapter.open(server) do |adapter|
          users = adapter.users(adapter.config.uid, '*', 100)
          users.each do |user|
            puts "\tDN: #{user.dn}\t #{adapter.config.uid}: #{user.uid}"
          end
        end
      end
    end
  end

  namespace :repo do
    desc "GitLab | Check the integrity of the repositories managed by GitLab"
    task check: :environment do
      namespace_dirs = Dir.glob(
        File.join(Gitlab.config.gitlab_shell.repos_path, '*')
      )

      namespace_dirs.each do |namespace_dir|
        repo_dirs = Dir.glob(File.join(namespace_dir, '*'))
        repo_dirs.each do |dir|
          puts "\nChecking repo at #{dir}"
          system(*%w(git fsck), chdir: dir)
        end
      end
    end
  end

  # Helper methods
  ##########################

  def fix_and_rerun
    puts "  Please #{"fix the error above"} and rerun the checks.".red
  end

  def for_more_information(*sources)
    sources = sources.shift if sources.first.is_a?(Array)

    puts "  For more information see:".blue
    sources.each do |source|
      puts "  #{source}"
    end
  end

  def finished_checking(component)
    puts ""
    puts "Checking #{component.yellow} ... #{"Finished".green}"
    puts ""
  end

  def see_database_guide
    "doc/install/databases.md"
  end

  def see_installation_guide_section(section)
    "doc/install/installation.md in section \"#{section}\""
  end

  def sudo_gitlab(command)
    "sudo -u #{gitlab_user} -H #{command}"
  end

  def gitlab_user
    Gitlab.config.gitlab.user
  end

  def start_checking(component)
    puts "Checking #{component.yellow} ..."
    puts ""
  end

  def try_fixing_it(*steps)
    steps = steps.shift if steps.first.is_a?(Array)

    puts "  Try fixing it:".blue
    steps.each do |step|
      puts "  #{step}"
    end
  end

  def check_gitlab_shell
    required_version = Gitlab::VersionInfo.new(gitlab_shell_major_version, gitlab_shell_minor_version, gitlab_shell_patch_version)
    current_version = Gitlab::VersionInfo.parse(gitlab_shell_version)

    print "GitLab Shell version >= #{required_version} ? ... "
    if current_version.valid? && required_version <= current_version
      puts "OK (#{current_version})".green
    else
      puts "FAIL. Please update gitlab-shell to #{required_version} from #{current_version}".red
    end
  end

  def check_ruby_version
    required_version = Gitlab::VersionInfo.new(2, 1, 0)
    current_version = Gitlab::VersionInfo.parse(run(%W(ruby --version)))

    print "Ruby version >= #{required_version} ? ... "

    if current_version.valid? && required_version <= current_version
      puts "yes (#{current_version})".green
    else
      puts "no".red
      try_fixing_it(
        "Update your ruby to a version >= #{required_version} from #{current_version}"
      )
      fix_and_rerun
    end
  end

  def check_git_version
    required_version = Gitlab::VersionInfo.new(1, 7, 10)
    current_version = Gitlab::VersionInfo.parse(run(%W(#{Gitlab.config.git.bin_path} --version)))

    puts "Your git bin path is \"#{Gitlab.config.git.bin_path}\""
    print "Git version >= #{required_version} ? ... "

    if current_version.valid? && required_version <= current_version
      puts "yes (#{current_version})".green
    else
      puts "no".red
      try_fixing_it(
        "Update your git to a version >= #{required_version} from #{current_version}"
      )
      fix_and_rerun
    end
  end

  def check_active_users
    puts "Active users: #{User.active.count}"
  end

  def omnibus_gitlab?
    Dir.pwd == '/opt/gitlab/embedded/service/gitlab-rails'
  end

  def sanitized_message(project)
    if should_sanitize?
      "#{project.namespace_id.to_s.yellow}/#{project.id.to_s.yellow} ... "
    else
      "#{project.name_with_namespace.yellow} ... "
    end
  end

  def should_sanitize?
    if ENV['SANITIZE'] == "true"
      true
    else
      false
    end
  end
end
