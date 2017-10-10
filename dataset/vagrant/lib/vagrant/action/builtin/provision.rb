require "log4r"

require_relative "mixin_provisioners"

module Vagrant
  module Action
    module Builtin
      class Provision
        include MixinProvisioners

        def initialize(app, env)
          @app             = app
          @logger          = Log4r::Logger.new("vagrant::action::builtin::provision")
        end

        def call(env)
          @env = env

          config_enabled = true
          config_enabled = env[:provision_enabled] if env.key?(:provision_enabled)

          provision_enabled = true

          ignore_sentinel = true
          if env.key?(:provision_ignore_sentinel)
            ignore_sentinel = env[:provision_ignore_sentinel]
          end
          if ignore_sentinel
            @logger.info("Ignoring sentinel check, forcing provision")
          end

          @logger.info("Checking provisioner sentinel file...")
          sentinel_path = env[:machine].data_dir.join("action_provision")
          update_sentinel = false
          if sentinel_path.file?
            contents = sentinel_path.read.chomp
            parts    = contents.split(":", 2)

            if parts.length == 1
              @logger.info("Old-style sentinel found! Not provisioning.")
              provision_enabled = false if !ignore_sentinel
              update_sentinel = true
            elsif parts[0] == "1.5" && parts[1] == env[:machine].id.to_s
              @logger.info("Sentinel found! Not provisioning.")
              provision_enabled = false if !ignore_sentinel
            else
              @logger.info("Sentinel found with another machine ID. Removing.")
              sentinel_path.unlink
            end
          end

          env[:provision_enabled] = provision_enabled if !env.key?(:provision_enabled)

          provisioner_instances(env).each do |p, _|
            p.configure(env[:machine].config)
          end

          @app.call(env)

          if !config_enabled
            env[:ui].info(I18n.t("vagrant.actions.vm.provision.disabled_by_config"))
            return
          end

          if !provision_enabled
            env[:ui].info(I18n.t("vagrant.actions.vm.provision.disabled_by_sentinel"))
          end

          if update_sentinel || !sentinel_path.file?
            @logger.info("Writing provisioning sentinel so we don't provision again")
            sentinel_path.open("w") do |f|
              f.write("1.5:#{env[:machine].id}")
            end
          end

          type_map = provisioner_type_map(env)
          provisioner_instances(env).each do |p, options|
            type_name = type_map[p]
            next if env[:provision_types] && \
              !env[:provision_types].include?(type_name) && \
              !env[:provision_types].include?(options[:name])

            next if !provision_enabled && options[:run] != :always

            name = type_name
            if options[:name]
              name = "#{options[:name]} (#{type_name})"
            end

            env[:ui].info(I18n.t(
              "vagrant.actions.vm.provision.beginning",
              provisioner: name))

            env[:hook].call(:provisioner_run, env.merge(
              callable: method(:run_provisioner),
              provisioner: p,
              provisioner_name: type_name,
            ))
          end
        end

        def run_provisioner(env)
          env[:provisioner].provision
        end
      end
    end
  end
end
