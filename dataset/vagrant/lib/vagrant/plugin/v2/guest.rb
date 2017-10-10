module Vagrant
  module Plugin
    module V2
      class Guest
        def detect?(machine)
          false
        end
      end
    end
  end
end
