module Vagrant
  module Plugin
    module V1
      class Host
        def self.match?
          nil
        end

        def self.precedence
          5
        end

        def initialize(ui)
          @ui = ui
        end

        def nfs?
          false
        end

        def nfs_export(id, ip, folders)
        end

        def nfs_prune(valid_ids)
        end
      end
    end
  end
end
