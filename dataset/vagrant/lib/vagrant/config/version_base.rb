module Vagrant
  module Config
    class VersionBase
      def self.init
        raise NotImplementedError
      end

      def self.finalize(obj)
        obj
      end

      def self.load(proc)
        raise NotImplementedError
      end

      def self.merge(old, new)
        raise NotImplementedError
      end

      def self.upgrade(old)
        raise NotImplementedError
      end
    end
  end
end
