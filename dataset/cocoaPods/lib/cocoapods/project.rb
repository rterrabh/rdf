require 'xcodeproj'

module Pod
  class Project < Xcodeproj::Project
    def initialize(path, skip_initialization = false,
        object_version = Xcodeproj::Constants::DEFAULT_OBJECT_VERSION)
      super(path, skip_initialization, object_version)
      @support_files_group = new_group('Targets Support Files')
      @refs_by_absolute_path = {}
      @pods = new_group('Pods')
      @development_pods = new_group('Development Pods')
      self.symroot = LEGACY_BUILD_ROOT
    end

    attr_reader :support_files_group

    attr_reader :pods

    attr_reader :development_pods

    public


    LEGACY_BUILD_ROOT = '${SRCROOT}/../build'

    def symroot=(symroot)
      root_object.build_configuration_list.build_configurations.each do |config|
        config.build_settings['SYMROOT'] = symroot
      end
    end

    public


    def add_pod_group(pod_name, path, development = false, absolute = false)
      raise '[BUG]' if pod_group(pod_name)

      parent_group = development ? development_pods : pods
      source_tree = absolute ? :absolute : :group

      group = parent_group.new_group(pod_name, path, source_tree)
      group
    end

    def pod_groups
      pods.children.objects + development_pods.children.objects
    end

    def pod_group(pod_name)
      pod_groups.find { |group| group.name == pod_name }
    end

    SPEC_SUBGROUPS = {
      :resources  => 'Resources',
      :frameworks => 'Frameworks',
    }

    def group_for_spec(spec_name, subgroup_key = nil)
      pod_name = Specification.root_name(spec_name)
      group = pod_group(pod_name)
      raise "[Bug] Unable to locate group for Pod named `#{pod_name}`" unless group
      if spec_name != pod_name
        subspecs_names = spec_name.gsub(pod_name + '/', '').split('/')
        subspecs_names.each do |name|
          group = group[name] || group.new_group(name)
        end
      end

      if subgroup_key
        subgroup_name = SPEC_SUBGROUPS[subgroup_key]
        raise ArgumentError, "Unrecognized subgroup key `#{subgroup_key}`" unless subgroup_name
        group = group[subgroup_name] || group.new_group(subgroup_name)
      end

      group
    end

    def pod_support_files_group(pod_name, dir)
      group = pod_group(pod_name)
      support_files_group = group['Support Files']
      unless support_files_group
        support_files_group = group.new_group('Support Files', dir)
      end
      support_files_group
    end

    public


    def add_file_reference(absolute_path, group, reflect_file_system_structure = false)
      file_path_name = Pathname.new(absolute_path)
      unless file_path_name.absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_path}"
      end

      if reflect_file_system_structure
        relative_path = file_path_name.relative_path_from(group.real_path)
        relative_dir = relative_path.dirname
        relative_dir.each_filename do|name|
          next if name == '.'
          group = group[name] || group.new_group(name, name)
        end
      end

      if ref = reference_for_path(absolute_path)
        ref
      else
        ref = group.new_file(absolute_path)
        @refs_by_absolute_path[absolute_path.to_s] = ref
      end
    end

    def reference_for_path(absolute_path)
      unless Pathname.new(absolute_path).absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_path}"
      end

      refs_by_absolute_path[absolute_path.to_s]
    end

    def add_podfile(podfile_path)
      podfile_ref = new_file(podfile_path, :project)
      podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      podfile_ref.last_known_file_type = 'text'
      podfile_ref
    end

    def add_build_configuration(name, type)
      build_configuration = super
      values = ["#{name.gsub(/[^a-zA-Z0-9_]/, '_').sub(/(^[0-9])/, '_\1').upcase}=1"]
      settings = build_configuration.build_settings
      definitions = Array(settings['GCC_PREPROCESSOR_DEFINITIONS'])
      values.each do |value|
        unless definitions.include?(value)
          definitions << value
        end
      end
      settings['GCC_PREPROCESSOR_DEFINITIONS'] = definitions
      build_configuration
    end

    private


    attr_reader :refs_by_absolute_path

  end
end
