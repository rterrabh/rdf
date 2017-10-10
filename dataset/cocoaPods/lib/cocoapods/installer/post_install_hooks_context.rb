module Pod
  class Installer
    class PostInstallHooksContext
      attr_accessor :sandbox_root

      attr_accessor :umbrella_targets

      def self.generate(sandbox, aggregate_targets)
        umbrella_targets_descriptions = []
        aggregate_targets.each do |umbrella|
          desc = UmbrellaTargetDescription.new
          desc.user_project_path = umbrella.user_project_path
          desc.user_target_uuids = umbrella.user_target_uuids
          desc.specs = umbrella.specs
          desc.platform_name = umbrella.platform.name
          desc.platform_deployment_target = umbrella.platform.deployment_target.to_s
          desc.cocoapods_target_label = umbrella.label
          umbrella_targets_descriptions << desc
        end

        result = new
        result.sandbox_root = sandbox.root.to_s
        result.umbrella_targets = umbrella_targets_descriptions
        result
      end

      class UmbrellaTargetDescription
        attr_accessor :user_project_path

        attr_accessor :user_target_uuids

        attr_accessor :specs

        attr_accessor :platform_name

        attr_accessor :platform_deployment_target

        attr_accessor :cocoapods_target_label
      end
    end
  end
end
