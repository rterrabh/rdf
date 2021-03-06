require 'yaml'
require 'pathname'
require 'dotenv'



namespace :sync do
  namespace :db do
    desc <<-DESC
      Syncs database from the selected environment to the local development environment.
      The database credentials will be read from your local config/database.yml file and a copy of the
      dump will be kept within the shared sync directory. The amount of backups that will be kept is
      declared in the sync_backups variable and defaults to 5.
    DESC
    task :down, :roles => :db, :only => {:primary => true} do
      run "mkdir -p #{shared_path}/sync"

      env = fetch :rails_env, 'production'
      filename = "database.#{env}.#{Time.now.strftime '%Y-%m-%d_%H:%M:%S'}.sql.bz2"
      on_rollback { delete "#{shared_path}/sync/#{filename}" }

      username, password, database, host = remote_database_config(env)
      hostcmd = host.nil? ? '' : "-h #{host}"

      puts "hostname: #{host}"
      puts "database: #{database}"

      opts = "-c --max_allowed_packet=128M --hex-blob --single-transaction --skip-extended-insert --quick"
      run "mysqldump #{opts} -u #{username} --password='#{password}' #{hostcmd} #{database} | bzip2 -9 > #{shared_path}/sync/#{filename}" do |channel, stream, data|
        puts data
      end
      purge_old_backups "database"

      download "#{shared_path}/sync/#{filename}", filename

      username, password, database = database_config('development')

      system "bzip2 -d -c #{filename} | mysql --max_allowed_packet=128M -u #{username} --password='#{password}' #{database}"
      system "rake db:migrate"
      system "rake db:test:prepare"

      logger.important "sync database from '#{env}' to local has finished"
    end
  end

  namespace :fs do
    desc <<-DESC
      Sync declared remote directories to the local development environment. The synced directories must be declared
      as an array of Strings with the sync_directories variable. The path is relative to the rails root.
    DESC
    task :down, :roles => :web, :once => true do

      server, port = host_and_port

      Array(fetch(:sync_directories, [])).each do |syncdir|
        unless File.directory? "#{syncdir}"
          logger.info "create local '#{syncdir}' folder"
          Dir.mkdir "#{syncdir}"
        end
        logger.info "sync #{syncdir} from #{server}:#{port} to local"
        destination, base = Pathname.new(syncdir).split
        system "rsync --verbose --archive --compress --copy-links --delete --stats --rsh='ssh -p #{port}' #{user}@#{server}:#{current_path}/#{syncdir} #{destination.to_s}"
      end

      logger.important "sync filesystem from remote to local finished"
    end
  end

  class EnvLoader
    def initialize(data)
      @env = Dotenv::Parser.call(data)
    end

    def with_loaded_env
      begin
        saved_env = ENV.to_hash.dup
        ENV.update(@env)
        yield
      ensure
        ENV.replace(saved_env)
      end
    end
  end

  def database_config(db)
    local_config = File.read('config/database.yml')
    local_env = File.read('.env')

    database = nil
    EnvLoader.new(local_env).with_loaded_env do
      database = YAML::load(ERB.new(local_config).result)
    end

    return database["#{db}"]['username'], database["#{db}"]['password'], database["#{db}"]['database'], database["#{db}"]['host']
  end

  def remote_database_config(db)
    remote_config = capture("cat #{current_path}/config/database.yml")
    remote_env = capture("cat #{current_path}/.env")

    database = nil
    EnvLoader.new(remote_env).with_loaded_env do
      database = YAML::load(ERB.new(remote_config).result)
    end

    return database["#{db}"]['username'], database["#{db}"]['password'], database["#{db}"]['database'], database["#{db}"]['host']
  end

  def host_and_port
    return roles[:web].servers.first.host, ssh_options[:port] || roles[:web].servers.first.port || 22
  end

  def purge_old_backups(base)
    count = fetch(:sync_backups, 5).to_i
    backup_files = capture("ls -xt #{shared_path}/sync/#{base}*").split.reverse
    if count >= backup_files.length
      logger.important "no old backups to clean up"
    else
      logger.info "keeping #{count} of #{backup_files.length} sync backups"
      delete_backups = (backup_files - backup_files.last(count)).join(" ")
      run "rm #{delete_backups}"
    end
  end
end
