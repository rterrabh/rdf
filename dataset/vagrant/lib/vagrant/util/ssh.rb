require "log4r"

require 'childprocess'

require "vagrant/util/file_mode"
require "vagrant/util/platform"
require "vagrant/util/safe_exec"
require "vagrant/util/safe_puts"
require "vagrant/util/subprocess"
require "vagrant/util/which"

module Vagrant
  module Util
    class SSH
      extend SafePuts

      LOGGER = Log4r::Logger.new("vagrant::util::ssh")

      def self.check_key_permissions(key_path)
        return if Platform.windows?

        LOGGER.debug("Checking key permissions: #{key_path}")
        stat = key_path.stat

        if !stat.owned? && Process.uid != 0
          raise Errors::SSHKeyBadOwner, key_path: key_path
        end

        if FileMode.from_octal(stat.mode) != "600"
          LOGGER.info("Attempting to correct key permissions to 0600")
          key_path.chmod(0600)

          stat = key_path.stat
          if FileMode.from_octal(stat.mode) != "600"
            raise Errors::SSHKeyBadPermissions, key_path: key_path
          end
        end
      rescue Errno::EPERM
        raise Errors::SSHKeyBadPermissions, key_path: key_path
      end

      def self.exec(ssh_info, opts={})
        ssh_path = Which.which("ssh")
        if !ssh_path
          if Platform.windows?
            raise Errors::SSHUnavailableWindows,
              host: ssh_info[:host],
              port: ssh_info[:port],
              username: ssh_info[:username],
              key_path: ssh_info[:private_key_path].join(", ")
          end

          raise Errors::SSHUnavailable
        end

        if Platform.windows?
          r = Subprocess.execute(ssh_path)
          if r.stdout.include?("PuTTY Link") || r.stdout.include?("Plink: command-line connection utility")
            raise Errors::SSHIsPuttyLink,
              host: ssh_info[:host],
              port: ssh_info[:port],
              username: ssh_info[:username],
              key_path: ssh_info[:private_key_path].join(", ")
          end
        end

        plain_mode = opts[:plain_mode]

        options = {}
        options[:host] = ssh_info[:host]
        options[:port] = ssh_info[:port]
        options[:username] = ssh_info[:username]
        options[:private_key_path] = ssh_info[:private_key_path]

        log_level = ssh_info[:log_level] || "FATAL"

        command_options = [
          "-p", options[:port].to_s,
          "-o", "Compression=yes",
          "-o", "DSAAuthentication=yes",
          "-o", "LogLevel=#{log_level}",
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null"]

        if !Platform.solaris? && !plain_mode
          command_options += ["-o", "IdentitiesOnly=yes"]
        end

        if !plain_mode
          options[:private_key_path].each do |path|
            command_options += ["-i", path.to_s]
          end
        end

        if ssh_info[:forward_x11]
          command_options += [
            "-o", "ForwardX11=yes",
            "-o", "ForwardX11Trusted=yes"]
        end

        if ssh_info[:proxy_command]
          command_options += ["-o", "ProxyCommand=#{ssh_info[:proxy_command]}"]
        end

        command_options += ["-o", "ForwardAgent=yes"] if ssh_info[:forward_agent]
        command_options.concat(opts[:extra_args]) if opts[:extra_args]

        host_string = options[:host]
        host_string = "#{options[:username]}@#{host_string}" if !plain_mode
        command_options.unshift(host_string)

        ENV["nodosfilewarning"] = "1" if Platform.cygwin?

        ssh = ssh_info[:ssh_command] || 'ssh'

        if !opts[:subprocess]
          LOGGER.info("Invoking SSH: #{ssh} #{command_options.inspect}")
          SafeExec.exec(ssh, *command_options)
          return
        end

        LOGGER.info("Executing SSH in subprocess: #{ssh} #{command_options.inspect}")
        process = ChildProcess.build(ssh, *command_options)
        process.io.inherit!
        process.start
        process.wait
        return process.exit_code
      end
    end
  end
end
