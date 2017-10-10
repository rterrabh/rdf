require "log4r"

require_relative "mixin_synced_folders"

module Vagrant
  module Action
    module Builtin
      class SyncedFolderCleanup
        include MixinSyncedFolders

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::action::builtin::synced_folder_cleanup")
        end

        def call(env)
          folders = synced_folders(env[:machine])

          folders.each_key do |impl_name|
            @logger.info("Invoking synced folder cleanup for: #{impl_name}")
            plugins[impl_name.to_sym][0].new.cleanup(
              env[:machine], impl_opts(impl_name, env))
          end

          @app.call(env)
        end
      end
    end
  end
end
