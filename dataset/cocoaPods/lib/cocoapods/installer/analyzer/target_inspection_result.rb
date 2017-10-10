module Pod
  class Installer
    class Analyzer
      class TargetInspectionResult
        attr_accessor :target_definition

        attr_accessor :project_path

        attr_accessor :project_target_uuids

        attr_accessor :build_configurations

        attr_accessor :platform

        attr_accessor :archs

        attr_accessor :recommends_frameworks
      end
    end
  end
end
