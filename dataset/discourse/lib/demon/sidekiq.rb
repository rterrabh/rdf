require "demon/base"

class Demon::Sidekiq < Demon::Base

  def self.prefix
    "sidekiq"
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def after_fork
    STDERR.puts "Loading Sidekiq in process id #{Process.pid}"
    require 'sidekiq/cli'
    Sidekiq::Logging.logger = nil
    cli = Sidekiq::CLI.instance
    cli.parse(["-c", GlobalSetting.sidekiq_workers.to_s])

    load Rails.root + "config/initializers/sidekiq.rb"
    cli.run
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end

end
