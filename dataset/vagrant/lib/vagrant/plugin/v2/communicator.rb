require "timeout"

module Vagrant
  module Plugin
    module V2
      class Communicator
        def self.match?(machine)
          true
        end

        def initialize(machine)
        end

        def ready?
          false
        end

        def wait_for_ready(duration)
          begin
            Timeout.timeout(duration) do
              while true
                return true if ready?
                sleep 0.5
              end
            end
          rescue Timeout::Error
          end

          return false
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
