require 'vagrant/action/builder'

module Vagrant
  module Action
    autoload :Runner,      'vagrant/action/runner'
    autoload :Warden,      'vagrant/action/warden'

    module Builtin
      autoload :BoxAdd,    "vagrant/action/builtin/box_add"
      autoload :BoxCheckOutdated, "vagrant/action/builtin/box_check_outdated"
      autoload :BoxRemove, "vagrant/action/builtin/box_remove"
      autoload :Call,    "vagrant/action/builtin/call"
      autoload :Confirm, "vagrant/action/builtin/confirm"
      autoload :ConfigValidate, "vagrant/action/builtin/config_validate"
      autoload :DestroyConfirm, "vagrant/action/builtin/destroy_confirm"
      autoload :EnvSet,  "vagrant/action/builtin/env_set"
      autoload :GracefulHalt, "vagrant/action/builtin/graceful_halt"
      autoload :HandleBox, "vagrant/action/builtin/handle_box"
      autoload :HandleBoxUrl, "vagrant/action/builtin/handle_box_url"
      autoload :HandleForwardedPortCollisions, "vagrant/action/builtin/handle_forwarded_port_collisions"
      autoload :IsState, "vagrant/action/builtin/is_state"
      autoload :Lock, "vagrant/action/builtin/lock"
      autoload :Message, "vagrant/action/builtin/message"
      autoload :Provision, "vagrant/action/builtin/provision"
      autoload :ProvisionerCleanup, "vagrant/action/builtin/provisioner_cleanup"
      autoload :SetHostname, "vagrant/action/builtin/set_hostname"
      autoload :SSHExec, "vagrant/action/builtin/ssh_exec"
      autoload :SSHRun,  "vagrant/action/builtin/ssh_run"
      autoload :SyncedFolders, "vagrant/action/builtin/synced_folders"
      autoload :SyncedFolderCleanup, "vagrant/action/builtin/synced_folder_cleanup"
      autoload :WaitForCommunicator, "vagrant/action/builtin/wait_for_communicator"
    end

    module General
      autoload :Package,  'vagrant/action/general/package'
    end

    def self.action_box_add
      Builder.new.tap do |b|
        b.use Builtin::BoxAdd
      end
    end

    def self.action_box_outdated
      Builder.new.tap do |b|
        b.use Builtin::BoxCheckOutdated
      end
    end

    def self.action_box_remove
      Builder.new.tap do |b|
        b.use Builtin::BoxRemove
      end
    end
  end
end
