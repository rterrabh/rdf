require "pathname"

require "vagrant/util/ssh"

module Vagrant
  module Action
    module Builtin
      class SSHExec
        include Vagrant::Util

        def initialize(app, env)
          @app = app
        end

        def call(env)
          info = env[:ssh_info]
          info ||= env[:machine].ssh_info

          raise Errors::SSHNotReady if info.nil?

          info[:private_key_path] ||= []

          if info[:private_key_path].empty? && info[:password]
            env[:ui].warn(I18n.t("vagrant.ssh_exec_password"))
          end

          SSH.exec(info, env[:ssh_opts])
        end
      end
    end
  end
end
