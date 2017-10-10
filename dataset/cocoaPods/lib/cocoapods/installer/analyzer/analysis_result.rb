module Pod
  class Installer
    class Analyzer
      class AnalysisResult
        attr_accessor :podfile_state

        attr_accessor :specs_by_target

        attr_accessor :specifications

        attr_accessor :sandbox_state

        attr_accessor :targets

        attr_accessor :target_inspections

        def all_user_build_configurations
          targets.reduce({}) do |result, target|
            result.merge(target.user_build_configurations)
          end
        end
      end
    end
  end
end
