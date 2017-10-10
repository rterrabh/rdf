require 'thread'

module Vagrant
  module Util
    class SafeChdir
      @@chdir_lock  = Mutex.new

      def self.safe_chdir(dir)
        lock = @@chdir_lock

        begin
          @@chdir_lock.synchronize {}
        rescue ThreadError
          lock = Mutex.new
        end

        lock.synchronize do
          Dir.chdir(dir) do
            return yield
          end
        end
      end
    end
  end
end

