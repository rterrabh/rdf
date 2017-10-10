require_relative "subprocess"
require_relative "which"

module Vagrant
  module Util
    class PowerShell
      def self.available?
        !!Which.which("powershell")
      end

      def self.execute(path, *args, **opts, &block)
        command = [
          "powershell",
          "-NoProfile",
          "-ExecutionPolicy", "Bypass",
          "&('#{path}')",
          args
        ].flatten

        command << opts

        Subprocess.execute(*command, &block)
      end

      def self.version
        command = [
          "powershell",
          "-NoProfile",
          "-ExecutionPolicy", "Bypass",
          "$PSVersionTable.PSVersion.Major"
        ].flatten

        r = Subprocess.execute(*command)
        return nil if r.exit_code != 0
        return r.stdout.chomp
      end
    end
  end
end
