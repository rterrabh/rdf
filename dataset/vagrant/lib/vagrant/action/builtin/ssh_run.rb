require "log4r"

require "vagrant/util/platform"
require "vagrant/util/ssh"
require "vagrant/util/shell_quote"

module Vagrant
  module Action
    module Builtin
      class SSHRun
        include Vagrant::Util

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::action::builtin::ssh_run")
        end

        def call(env)
          info = env[:machine].ssh_info

          raise Errors::SSHNotReady if info.nil?

          info[:private_key_path] ||= []

          if info[:private_key_path].empty?
            raise Errors::SSHRunRequiresKeys
          end

          command = ShellQuote.escape(env[:ssh_run_command], "'")
          command = "#{env[:machine].config.ssh.shell} -c '#{command}'"

          opts = env[:ssh_opts] || {}
          opts[:extra_args] ||= []

          if !opts[:extra_args].include?("-t") && !opts[:extra_args].include?("-T")
            opts[:extra_args] << "-t"
          end

          opts[:extra_args] << command
          opts[:subprocess] = true
          env[:ssh_run_exit_status] = Util::SSH.exec(info, opts)

          @app.call(env)
        end
      end
    end
  end
end
