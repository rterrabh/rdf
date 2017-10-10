require "log4r"

require 'vagrant/util/platform'

require_relative "mixin_synced_folders"

module Vagrant
  module Action
    module Builtin
      class SyncedFolders
        include MixinSyncedFolders

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::action::builtin::synced_folders")
        end

        def call(env)
          opts = {
            cached: !!env[:synced_folders_cached],
            config: env[:synced_folders_config],
          }

          folders = synced_folders(env[:machine], **opts)
          original_folders = folders

          folders.each do |impl_name, fs|
            @logger.info("Synced Folder Implementation: #{impl_name}")

            fs.each do |id, data|
              @logger.info("  - #{id}: #{data[:hostpath]} => #{data[:guestpath]}")
            end
          end

          folders.each do |_, fs|
            fs.each do |id, data|
              next if data[:hostpath_exact]

              data[:hostpath] = File.expand_path(
                data[:hostpath], env[:root_path])

              if File.file?(data[:hostpath])
                data[:hostpath] = File.realpath(data[:hostpath])
              end

              if !File.directory?(data[:hostpath]) && data[:create]
                @logger.info("Creating shared folder host directory: #{data[:hostpath]}")
                begin
                  Pathname.new(data[:hostpath]).mkpath
                rescue Errno::EACCES
                  raise Vagrant::Errors::SharedFolderCreateFailed,
                    path: data[:hostpath]
                end
              end

              if File.directory?(data[:hostpath])
                data[:hostpath] = File.realpath(data[:hostpath])
                data[:hostpath] = Util::Platform.fs_real_path(data[:hostpath]).to_s
              end
            end
          end

          folders = folders.map do |impl_name, fs|
            instance = plugins[impl_name.to_sym][0].new
            [instance, impl_name, fs]
          end

          folders.each do |impl, impl_name, fs|
            if !env[:synced_folders_disable]
              @logger.info("Invoking synced folder prepare for: #{impl_name}")
              impl.prepare(env[:machine], fs, impl_opts(impl_name, env))
            end
          end

          @app.call(env)

          folders.each do |impl, impl_name, fs|
            if !env[:synced_folders_disable]
              @logger.info("Invoking synced folder enable: #{impl_name}")
              impl.enable(env[:machine], fs, impl_opts(impl_name, env))
              next
            end

            to_disable = {}
            fs.each do |id, data|
              next if !env[:synced_folders_disable].include?(id)
              to_disable[id] = data
            end

            @logger.info("Invoking synced folder disable: #{impl_name}")
            to_disable.each do |id, _|
              @logger.info("  - Disabling: #{id}")
            end
            impl.disable(env[:machine], to_disable, impl_opts(impl_name, env))
          end

          if env[:synced_folders_disable]
            all = synced_folders(env[:machine], cached: true)
            all.each do |impl, fs|
              fs.keys.each do |id|
                if env[:synced_folders_disable].include?(id)
                  fs.delete(id)
                end
              end
            end

            save_synced_folders(env[:machine], all)
          else
            save_synced_folders(env[:machine], original_folders, merge: true)
          end
        end
      end
    end
  end
end
