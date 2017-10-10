require "json"
require "set"

require 'vagrant/util/scoped_hash_override'

module Vagrant
  module Action
    module Builtin
      module MixinSyncedFolders
        include Vagrant::Util::ScopedHashOverride

        def default_synced_folder_type(machine, plugins)
          ordered = []

          plugins.each do |key, data|
            impl     = data[0]
            priority = data[1]

            ordered << [priority, key, impl]
          end

          ordered = ordered.sort { |a, b| b[0] <=> a[0] }

          allowed_types = machine.config.vm.allowed_synced_folder_types
          if allowed_types
            ordered = allowed_types.map do |type|
              ordered.find do |_, key, impl|
                key == type
              end
            end.compact
          end

          ordered.each do |_, key, impl|
            return key if impl.new.usable?(machine)
          end

          return nil
        end

        def impl_opts(name, env)
          {}.tap do |result|
            env.each do |k, v|
              if k.to_s.start_with?("#{name}_")
                k = k.dup rescue k
                v = v.dup rescue v

                result[k] = v
              end
            end
          end
        end

        def plugins
          @plugins ||= Vagrant.plugin("2").manager.synced_folders
        end

        def save_synced_folders(machine, folders, **opts)
          if opts[:merge]
            existing = cached_synced_folders(machine)
            if existing
              folders.each do |impl, fs|
                existing[impl] ||= {}
                fs.each do |id, data|
                  existing[impl][id] = data
                end
              end

              folders = existing
            end
          end

          machine.data_dir.join("synced_folders").open("w") do |f|
            f.write(JSON.dump(folders))
          end
        end

        def synced_folders(machine, **opts)
          return cached_synced_folders(machine) if opts[:cached]

          config = opts[:config]
          config ||= machine.config.vm
          config_folders = config.synced_folders
          folders = {}

          config_folders.each do |id, data|
            next if data[:disabled]

            impl = ""
            impl = data[:type].to_sym if data[:type] && !data[:type].empty?

            if impl != ""
              impl_class = plugins[impl]
              if !impl_class
                raise "Internal error. Report this as a bug. Invalid: #{data[:type]}"
              end

              if !opts[:disable_usable_check]
                if !impl_class[0].new.usable?(machine, true)
                  raise Errors::SyncedFolderUnusable, type: data[:type].to_s
                end
              end
            end

            folders[impl] ||= {}
            folders[impl][id] = data.dup
          end

          if folders.key?("") && !folders[""].empty?
            default_impl = default_synced_folder_type(machine, plugins)
            if !default_impl
              types = plugins.to_hash.keys.map { |t| t.to_s }.sort.join(", ")
              raise Errors::NoDefaultSyncedFolderImpl, types: types
            end

            folders[default_impl] ||= {}
            folders[default_impl].merge!(folders[""])
            folders.delete("")
          end

          folders.dup.each do |impl_name, fs|
            new_fs = {}
            fs.each do |id, data|
              id         = data[:id] if data[:id]
              new_fs[id] = scoped_hash_override(data, impl_name)
            end

            folders[impl_name] = new_fs
          end

          return folders
        end

        def synced_folders_diff(one, two)
          existing_ids = {}
          one.each do |impl, fs|
            fs.each do |id, data|
              existing_ids[id] = data
            end
          end

          result = Hash.new { |h, k| h[k] = Set.new }
          two.each do |impl, fs|
            fs.each do |id, data|
              existing = existing_ids.delete(id)
              if !existing
                result[:added] << id
                next
              end

              if existing[:hostpath] != data[:hostpath] ||
                existing[:guestpath] != data[:guestpath]
                result[:modified] << id
              end
            end
          end

          existing_ids.each do |k, _|
            result[:removed] << k
          end

          result
        end

        protected

        def cached_synced_folders(machine)
          JSON.parse(machine.data_dir.join("synced_folders").read).tap do |r|
            r.keys.each do |k|
              r[k].each do |ik, v|
                v.keys.each do |vk|
                  v[vk.to_sym] = v[vk]
                  v.delete(vk)
                end
              end

              r[k.to_sym] = r[k]
              r.delete(k)
            end
          end
        rescue Errno::ENOENT
          return {}
        end
      end
    end
  end
end
