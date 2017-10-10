module Pod
  class Installer
    class PreInstallHooksContext
      attr_accessor :sandbox_root

      attr_accessor :podfile

      attr_accessor :sandbox

      attr_accessor :lockfile

      def self.generate(sandbox, podfile, lockfile)
        result = new
        result.podfile = podfile
        result.sandbox = sandbox
        result.lockfile = lockfile
        result
      end
    end
  end
end
