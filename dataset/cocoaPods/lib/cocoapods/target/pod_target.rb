module Pod
  class PodTarget < Target
    attr_reader :specs

    attr_reader :target_definitions

    attr_reader :build_headers

    attr_reader :scoped
    alias_method :scoped?, :scoped

    attr_accessor :dependent_targets

    def initialize(specs, target_definitions, sandbox, scoped = false)
      raise "Can't initialize a PodTarget without specs!" if specs.nil? || specs.empty?
      raise "Can't initialize a PodTarget without TargetDefinition!" if target_definitions.nil? || target_definitions.empty?
      super()
      @specs = specs
      @target_definitions = target_definitions
      @sandbox = sandbox
      @scoped = scoped
      @build_headers  = Sandbox::HeadersStore.new(sandbox, 'Private')
      @file_accessors = []
      @resource_bundle_targets = []
      @dependent_targets = []
    end

    def scoped
      target_definitions.map do |target_definition|
        PodTarget.new(specs, [target_definition], sandbox, true).tap do |target|
          target.file_accessors = file_accessors
          target.user_build_configurations = user_build_configurations
          target.native_target = native_target
          target.archs = archs
          target.dependent_targets = dependent_targets.flat_map(&:scoped)
        end
      end
    end

    def label
      if scoped?
        "#{target_definitions.first.label}-#{root_spec.name}"
      else
        root_spec.name
      end
    end

    def platform
      @platform ||= target_definitions.first.platform
    end

    def podfile
      target_definitions.first.podfile
    end

    def product_module_name
      root_spec.module_name
    end

    attr_accessor :file_accessors

    attr_reader :resource_bundle_targets

    def should_build?
      source_files = file_accessors.flat_map(&:source_files)
      source_files -= file_accessors.flat_map(&:headers)
      !source_files.empty?
    end

    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    def uses_swift?
      file_accessors.any? do |file_accessor|
        file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
      end
    end

    def root_spec
      specs.first.root
    end

    def pod_name
      root_spec.name
    end

    def resources_bundle_target_label(bundle_name)
      "#{label}-#{bundle_name}"
    end

    def dependencies
      spec_consumers.flat_map do |consumer|
        consumer.dependencies.map { |dep| Specification.root_name(dep.name) }
      end.uniq
    end

    def include_in_build_config?(target_definition, configuration_name)
      whitelists = target_definition_dependencies(target_definition).map do |dependency|
        target_definition.pod_whitelisted_for_configuration?(dependency.name, configuration_name)
      end.uniq

      if whitelists.empty?
        return true
      elsif whitelists.count == 1
        whitelists.first
      else
        raise Informative, "The subspecs of `#{pod_name}` are linked to " \
          "different build configurations for the `#{target_definition}` " \
          'target. CocoaPods does not currently support subspecs across ' \
          'different build configurations.'
      end
    end

    def inhibit_warnings?
      whitelists = target_definitions.map do |target_definition|
        target_definition.inhibits_warnings_for_pod?(root_spec.name)
      end.uniq

      if whitelists.empty?
        return false
      elsif whitelists.count == 1
        whitelists.first
      else
        UI.warn "The pod `#{pod_name}` is linked to different targets " \
          "(#{target_definitions.map(&:label)}), which contain different " \
          'settings to inhibit warnings. CocoaPods does not currently ' \
          'support different settings and will fall back to your preference ' \
          'set in the root target definition.'
        return podfile.root_target_definitions.first.inhibits_warnings_for_pod?(root_spec.name)
      end
    end

    def configuration_build_dir
      if scoped?
        "$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/#{target_definitions.first.label}"
      else
        '$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
      end
    end

    private

    def target_definition_dependencies(target_definition)
      target_definition.dependencies.select do |dependency|
        Specification.root_name(dependency.name) == pod_name
      end
    end
  end
end
