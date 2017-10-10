module Pod
  class Installer
    class UserProjectIntegrator
      class TargetIntegrator
        class XCConfigIntegrator
          def self.integrate(pod_bundle, targets)
            changes = false
            targets.each do |target|
              target.build_configurations.each do |config|
                changes = true if update_to_cocoapods_0_34(pod_bundle, targets)
                changes = true if set_target_xcconfig(pod_bundle, target, config)
              end
            end
            changes
          end

          private


          def self.update_to_cocoapods_0_34(pod_bundle, targets)
            sandbox = pod_bundle.sandbox
            changes = false
            targets.map(&:project).uniq.each do |project|
              file_refs = project.files.select do |file_ref|
                path = file_ref.path.to_s
                if File.extname(path) == '.xcconfig'
                  absolute_path = file_ref.real_path.to_s
                  absolute_path.start_with?(sandbox.root.to_s) &&
                    !absolute_path.start_with?(sandbox.target_support_files_root.to_s)
                end
              end

              file_refs.uniq.each do |file_ref|
                UI.message "- Removing (#{file_ref.path})" do
                  file_ref.remove_from_project
                end
              end

              changes = true unless file_refs.empty?
            end
            changes
          end

          def self.set_target_xcconfig(pod_bundle, target, config)
            path = pod_bundle.xcconfig_relative_path(config.name)
            group = config.project['Pods'] || config.project.new_group('Pods')
            file_ref = group.files.find { |f| f.path == path }
            if config.base_configuration_reference &&
                config.base_configuration_reference != file_ref
              unless xcconfig_includes_target_xcconfig?(config.base_configuration_reference, path)
                UI.warn 'CocoaPods did not set the base configuration of your ' \
                'project because your project already has a custom ' \
                'config set. In order for CocoaPods integration to work at ' \
                'all, please either set the base configurations of the target ' \
                "`#{target.name}` to `#{path}` or include the `#{path}` in your " \
                'build configuration.'
              end
            elsif config.base_configuration_reference.nil? || file_ref.nil?
              file_ref ||= group.new_file(path)
              config.base_configuration_reference = file_ref
              return true
            end
            false
          end

          private


          def self.print_override_warning(pod_bundle, target, config, key)
            actions = [
              'Use the `$(inherited)` flag, or',
              'Remove the build settings from the target.',
            ]
            message = "The `#{target.name} [#{config.name}]` " \
              "target overrides the `#{key}` build setting defined in " \
              "`#{pod_bundle.xcconfig_relative_path(config.name)}'. " \
              'This can lead to problems with the CocoaPods installation'
            UI.warn(message, actions)
          end

          SILENCE_WARNINGS_STRING = '// @COCOAPODS_SILENCE_WARNINGS@ //'
          def self.xcconfig_includes_target_xcconfig?(base_config_ref, target_config_path)
            return unless base_config_ref && base_config_ref.real_path.file?
            regex = /
              ^(
                (\s*                                  # Possible, but unlikely, space before include statement
                  \#include\s+                        # Include statement
                  ['"]                                # Open quote
                  (.*\/)?                             # Possible prefix to path
                  ['"]                                # Close quote
                )
                |
                (#{Regexp.quote(SILENCE_WARNINGS_STRING)}) # Token to treat xcconfig as good and silence pod install warnings
              )
            /x
            base_config_ref.real_path.readlines.find { |line| line =~ regex }
          end
        end
      end
    end
  end
end
