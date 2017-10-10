module Vagrant
  module Util
    module SilenceWarnings
      def self.silence!
        original = $VERBOSE
        $VERBOSE = nil
        return yield
      ensure
        $VERBOSE = original
      end
    end
  end
end
