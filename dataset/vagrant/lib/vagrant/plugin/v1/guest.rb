module Vagrant
  module Plugin
    module V1
      class Guest
        class BaseError < Errors::VagrantError
          error_namespace("vagrant.guest.base")
        end

        include Vagrant::Util

        attr_reader :vm

        def initialize(vm)
          @vm = vm
        end

        def distro_dispatch
        end

        def halt
          raise BaseError, _key: :unsupported_halt
        end

        def mount_shared_folder(name, guestpath, options)
          raise BaseError, _key: :unsupported_shared_folder
        end

        def mount_nfs(ip, folders)
          raise BaseError, _key: :unsupported_nfs
        end

        def configure_networks(networks)
          raise BaseError, _key: :unsupported_configure_networks
        end

        def change_host_name(name)
          raise BaseError, _key: :unsupported_host_name
        end
      end
    end
  end
end
