module Vagrant
  module Plugin
    module V1
      class Communicator
        def self.match?(machine)
          false
        end

        def initialize(machine)
        end

        def ready?
          false
        end

        def download(from, to)
        end

        def upload(from, to)
        end

        def execute(command, opts=nil)
        end

        def sudo(command, opts=nil)
        end

        def test(command, opts=nil)
        end
      end
    end
  end
end
