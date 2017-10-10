require 'active_support/core_ext/string/inflections'

module Pod
  class Installer
    class UserProjectIntegrator
      class TargetIntegrator
        autoload :XCConfigIntegrator, 'cocoapods/installer/user_project_integrator/target_integrator/xcconfig_integrator'

        EMBED_FRAMEWORK_TARGET_TYPES = [:application, :unit_test_bundle, :app_extension, :watch_extension, :watch2_extension].freeze

        EMBED_FRAMEWORK_PHASE_NAME = 'Embed Pods Frameworks'.freeze

        attr_reader :target

        def initialize(target)
          @target = target
        end

        def integrate!
          UI.section(integration_message) do
            project_is_dirty = [
              XCConfigIntegrator.integrate(target, native_targets),
              update_to_cocoapods_0_34,
              update_to_cocoapods_0_37_1,
              update_to_cocoapods_0_39,
              unless native_targets_to_integrate.empty?
                add_pods_library
                add_embed_frameworks_script_phase
                add_copy_resources_script_phase
                add_check_manifest_lock_script_phase
                true
              end,
            ].any?

            if project_is_dirty
              user_project.save
            else
              FileUtils.touch(user_project.path + 'project.pbxproj')
            end
          end
        end

        def inspect
          "#<#{self.class} for target `#{target.label}'>"
        end

        private


        def update_to_cocoapods_0_34
          phases = native_targets.map do |target|
            target.shell_script_build_phases.select do |bp|
              bp.name == 'Copy Pods Resources'
            end
          end.flatten

          script_path = target.copy_resources_script_relative_path
          shell_script = %("#{script_path}"\n)
          changes = false
          phases.each do |phase|
            unless phase.shell_script == shell_script
              phase.shell_script = shell_script
              changes = true
            end
          end
          changes
        end

        def update_to_cocoapods_0_37_1
          targets_to_embed = native_targets.select do |target|
            EMBED_FRAMEWORK_TARGET_TYPES.include?(target.symbol_type)
          end
          (native_targets - targets_to_embed).any? do |native_target|
            remove_embed_frameworks_script_phase(native_target)
          end
        end

        def update_to_cocoapods_0_39
          requires_update = native_targets_to_embed_in.any? do |target|
            !target.shell_script_build_phases.find { |bp| bp.name == 'Embed Pods Frameworks' }
          end
          if requires_update
            add_embed_frameworks_script_phase
            true
          end
        end

        def add_pods_library
          frameworks = user_project.frameworks_group
          native_targets_to_integrate.each do |native_target|
            build_phase = native_target.frameworks_build_phase

            old_product_name = target.requires_frameworks? ? target.static_library_name : target.framework_name
            old_product_ref = frameworks.files.find { |f| f.path == old_product_name }
            if old_product_ref.present?
              UI.message("Removing old Pod product reference #{old_product_name} from project.")
              build_phase.remove_file_reference(old_product_ref)
              frameworks.remove_reference(old_product_ref)
            end

            target_basename = target.product_basename
            new_product_ref = frameworks.files.find { |f| f.path == target.product_name } ||
              frameworks.new_product_ref_for_target(target_basename, target.product_type)
            build_file = build_phase.build_file(new_product_ref) ||
              build_phase.add_file_reference(new_product_ref, true)
            if target.requires_frameworks?
              build_file.settings ||= {}
              build_file.settings['ATTRIBUTES'] = ['Weak']
            end
          end
        end

        def add_embed_frameworks_script_phase
          native_targets_to_embed_in.each do |native_target|
            phase = create_or_update_build_phase(native_target, EMBED_FRAMEWORK_PHASE_NAME)
            script_path = target.embed_frameworks_script_relative_path
            phase.shell_script = %("#{script_path}"\n)
          end
        end

        def remove_embed_frameworks_script_phase(native_target)
          embed_build_phase = native_target.shell_script_build_phases.find { |bp| bp.name == EMBED_FRAMEWORK_PHASE_NAME }
          return false unless embed_build_phase.present?
          native_target.build_phases.delete(embed_build_phase)
          true
        end

        def add_copy_resources_script_phase
          phase_name = 'Copy Pods Resources'
          native_targets_to_integrate.each do |native_target|
            phase = create_or_update_build_phase(native_target, phase_name)
            script_path = target.copy_resources_script_relative_path
            phase.shell_script = %("#{script_path}"\n)
          end
        end

        def add_check_manifest_lock_script_phase
          phase_name = 'Check Pods Manifest.lock'
          native_targets_to_integrate.each do |native_target|
            phase = create_or_update_build_phase(native_target, phase_name)
            native_target.build_phases.unshift(phase).uniq!
            phase.shell_script = <<-EOS.strip_heredoc
              diff "${PODS_ROOT}/../Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
              if [[ $? != 0 ]] ; then
                  cat << EOM
              error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
              EOM
                  exit 1
              fi
            EOS
          end
        end

        private


        def native_targets
          @native_targets ||= target.user_targets(user_project)
        end

        def native_targets_to_embed_in
          native_targets_to_integrate.select do |target|
            EMBED_FRAMEWORK_TARGET_TYPES.include?(target.symbol_type)
          end
        end

        def native_targets_to_integrate
          unless @native_targets_to_integrate
            @native_targets_to_integrate = native_targets.reject do |native_target|
              native_target.frameworks_build_phase.files.any? do |build_file|
                file_ref = build_file.file_ref
                file_ref &&
                  file_ref.isa == 'PBXFileReference' &&
                  file_ref.display_name == target.product_name
              end
            end
          end
          @native_targets_to_integrate
        end

        def user_project
          @user_project ||= Xcodeproj::Project.open(target.user_project_path)
        end

        def spec_consumers
          @spec_consumers ||= target.pod_targets.map(&:file_accessors).flatten.map(&:spec_consumer)
        end

        def integration_message
          "Integrating target `#{target.name}` " \
            "(#{UI.path target.user_project_path} project)"
        end

        def create_or_update_build_phase(target, phase_name, phase_class = Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
          target.build_phases.grep(phase_class).find { |phase| phase.name == phase_name } ||
            target.project.new(phase_class).tap do |phase|
              UI.message("Adding Build Phase '#{phase_name}' to project.") do
                phase.name = phase_name
                phase.show_env_vars_in_log = '0'
                target.build_phases << phase
              end
            end
        end
      end
    end
  end
end
