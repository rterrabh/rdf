module Pod
  class AggregateTarget < Target
    attr_reader :target_definition

    def initialize(target_definition, sandbox)
      super()
      @target_definition = target_definition
      @sandbox = sandbox
      @pod_targets = []
      @file_accessors = []
      @xcconfigs = {}
    end

    def label
      target_definition.label.to_s
    end

    def product_module_name
      c99ext_identifier(label)
    end

    def platform
      @platform ||= target_definition.platform
    end

    def podfile
      target_definition.podfile
    end

    attr_accessor :client_root

    attr_accessor :user_project_path

    attr_accessor :user_target_uuids

    def user_targets(project = nil)
      return [] unless user_project_path
      project ||= Xcodeproj::Project.open(user_project_path)
      user_target_uuids.map do |uuid|
        native_target = project.objects_by_uuid[uuid]
        unless native_target
          raise Informative, '[Bug] Unable to find the target with ' \
            "the `#{uuid}` UUID for the `#{self}` integration library"
        end
        native_target
      end
    end

    attr_reader :xcconfigs

    attr_accessor :pod_targets

    def pod_targets_for_build_configuration(build_configuration)
      pod_targets.select do |pod_target|
        pod_target.include_in_build_config?(target_definition, build_configuration)
      end
    end

    def specs
      pod_targets.map(&:specs).flatten
    end

    def specs_by_build_configuration
      result = {}
      user_build_configurations.keys.each do |build_configuration|
        result[build_configuration] = pod_targets_for_build_configuration(build_configuration).
          flat_map(&:specs)
      end
      result
    end

    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    def uses_swift?
      pod_targets.any?(&:uses_swift?)
    end



    def acknowledgements_basepath
      support_files_dir + "#{label}-acknowledgements"
    end

    def copy_resources_script_path
      support_files_dir + "#{label}-resources.sh"
    end

    def embed_frameworks_script_path
      support_files_dir + "#{label}-frameworks.sh"
    end

    def relative_pods_root
      "${SRCROOT}/#{sandbox.root.relative_path_from(client_root)}"
    end

    def xcconfig_relative_path(config_name)
      relative_to_srcroot(xcconfig_path(config_name)).to_s
    end

    def copy_resources_script_relative_path
      "${SRCROOT}/#{relative_to_srcroot(copy_resources_script_path)}"
    end

    def embed_frameworks_script_relative_path
      "${SRCROOT}/#{relative_to_srcroot(embed_frameworks_script_path)}"
    end

    def scoped_configuration_build_dir
      "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/#{target_definition.label}"
    end

    private


    def relative_to_srcroot(path)
      path.relative_path_from(client_root).to_s
    end
  end
end
