require "log4r"

module Vagrant
  module Action
    module Builtin
      class BoxRemove
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::action::builtin::box_remove")
        end

        def call(env)
          box_name     = env[:box_name]
          box_provider = env[:box_provider]
          box_provider = box_provider.to_sym if box_provider
          box_version  = env[:box_version]

          boxes = {}
          env[:box_collection].all.each do |n, v, p|
            boxes[n] ||= {}
            boxes[n][p] ||= []
            boxes[n][p] << v
          end

          all_box = boxes[box_name]
          if !all_box
            raise Errors::BoxRemoveNotFound, name: box_name
          end

          all_versions = nil
          if !box_provider
            if all_box.length == 1
              all_versions = all_box.values.first
              box_provider = all_box.keys.first
            else
              raise Errors::BoxRemoveMultiProvider,
                name: box_name,
                providers: all_box.keys.map(&:to_s).sort.join(", ")
            end
          else
            all_versions = all_box[box_provider]
            if !all_versions
              raise Errors::BoxRemoveProviderNotFound,
                name: box_name,
                provider: box_provider.to_s,
                providers: all_box.keys.map(&:to_s).sort.join(", ")
            end
          end

          if !box_version
            if all_versions.length == 1
              box_version = all_versions.first
            else
              raise Errors::BoxRemoveMultiVersion,
                name: box_name,
                provider: box_provider.to_s,
                versions: all_versions.sort.map { |k| " * #{k}" }.join("\n")
            end
          elsif !all_versions.include?(box_version)
            raise Errors::BoxRemoveVersionNotFound,
              name: box_name,
              provider: box_provider.to_s,
              version: box_version,
              versions: all_versions.sort.map { |k| " * #{k}" }.join("\n")
          end

          box = env[:box_collection].find(
            box_name, box_provider, box_version)

          users = box.in_use?(env[:machine_index]) || []
          users = users.find_all { |u| u.valid?(env[:home_path]) }
          if !users.empty?
            users = users.map do |entry|
              "#{entry.name} (ID: #{entry.id})"
            end.join("\n")

            force_key = :force_confirm_box_remove
            message   = I18n.t(
              "vagrant.commands.box.remove_in_use_query",
              name: box.name,
              provider: box.provider,
              version: box.version,
              users: users) + " "

            stack = Builder.new.tap do |b|
              b.use Confirm, message, force_key
            end

            result = env[:action_runner].run(stack, env)
            if !result[:result]
              return @app.call(env)
            end
          end

          env[:ui].info(I18n.t("vagrant.commands.box.removing",
                              name: box.name,
                              provider: box.provider,
                              version: box.version))
          box.destroy!

          env[:box_removed] = box

          @app.call(env)
        end
      end
    end
  end
end
