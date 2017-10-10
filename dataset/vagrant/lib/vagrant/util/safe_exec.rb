module Vagrant
  module Util
    class SafeExec
      def self.exec(command, *args)
        rescue_from = []
        rescue_from << Errno::EOPNOTSUPP if defined?(Errno::EOPNOTSUPP)
        rescue_from << Errno::E045 if defined?(Errno::E045)
        rescue_from << SystemCallError

        fork_instead = false
        begin
          pid = nil
          pid = fork if fork_instead
          Kernel.exec(command, *args) if pid.nil?
          Process.wait(pid) if pid
        rescue *rescue_from
          raise if fork_instead

          fork_instead = true
          retry
        end
      end
    end
  end
end
