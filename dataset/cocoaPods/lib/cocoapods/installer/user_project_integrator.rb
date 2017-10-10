require 'xcodeproj/workspace'
require 'xcodeproj/project'

require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/conversions'

module Pod
  class Installer
    class UserProjectIntegrator
      autoload :TargetIntegrator, 'cocoapods/installer/user_project_integrator/target_integrator'

      attr_reader :podfile


      attr_reader :sandbox

      attr_reader :installation_root

      attr_reader :targets

      def initialize(podfile, sandbox, installation_root, targets)
        @podfile = podfile
        @sandbox = sandbox
        @installation_root = installation_root
        @targets = targets
      end

      def integrate!
        create_workspace
        integrate_user_targets
        warn_about_empty_podfile
        warn_about_xcconfig_overrides
      end


      private


      def create_workspace
        all_projects = user_project_paths.sort.push(sandbox.project_path).uniq
        file_references = all_projects.map do |path|
          relative_path = path.relative_path_from(workspace_path.dirname).to_s
          Xcodeproj::Workspace::FileReference.new(relative_path, 'group')
        end

        if workspace_path.exist?
          workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          new_file_references = file_references - workspace.file_references
          unless new_file_references.empty?
            workspace.file_references.concat(new_file_references)
            workspace.save_as(workspace_path)
          end

        else
          UI.notice "Please close any current Xcode sessions and use `#{workspace_path.basename}` for this project from now on."
          workspace = Xcodeproj::Workspace.new(*file_references)
          workspace.save_as(workspace_path)
        end
      end

      def integrate_user_targets
        targets_to_integrate.sort_by(&:name).each do |target|
          TargetIntegrator.new(target).integrate!
        end
      end

      def warn_about_empty_podfile
        if podfile.target_definitions.values.all?(&:empty?)
          UI.warn '[!] The Podfile does not contain any dependencies.'
        end
      end

      IGNORED_KEYS = %w(CODE_SIGN_IDENTITY).freeze
      INHERITED_FLAGS = %w($(inherited) ${inherited}).freeze

      def warn_about_xcconfig_overrides
        targets.each do |aggregate_target|
          aggregate_target.user_targets.each do |user_target|
            user_target.build_configurations.each do |config|
              xcconfig = aggregate_target.xcconfigs[config.name]
              if xcconfig
                (xcconfig.to_hash.keys - IGNORED_KEYS).each do |key|
                  target_values = config.build_settings[key]
                  if target_values &&
                      !INHERITED_FLAGS.any? { |flag| target_values.include?(flag) }
                    print_override_warning(aggregate_target, user_target, config, key)
                  end
                end
              end
            end
          end
        end
      end

      private


      def workspace_path
        if podfile.workspace_path
          declared_path = podfile.workspace_path
          path_with_ext = File.extname(declared_path) == '.xcworkspace' ? declared_path : "#{declared_path}.xcworkspace"
          podfile_dir   = File.dirname(podfile.defined_in_file || '')
          absolute_path = File.expand_path(path_with_ext, podfile_dir)
          Pathname.new(absolute_path)
        elsif user_project_paths.count == 1
          project = user_project_paths.first.basename('.xcodeproj')
          installation_root + "#{project}.xcworkspace"
        else
          raise Informative, 'Could not automatically select an Xcode ' \
            "workspace. Specify one in your Podfile like so:\n\n"       \
            "    workspace 'path/to/Workspace.xcworkspace'\n"
        end
      end

      def user_project_paths
        targets.map(&:user_project_path).compact.uniq
      end

      def targets_to_integrate
        targets.reject { |target| target.target_definition.empty? }
      end

      def print_override_warning(aggregate_target, user_target, config, key)
        actions = [
          'Use the `$(inherited)` flag, or',
          'Remove the build settings from the target.',
        ]
        message = "The `#{user_target.name} [#{config.name}]` " \
          "target overrides the `#{key}` build setting defined in " \
          "`#{aggregate_target.xcconfig_relative_path(config.name)}'. " \
          'This can lead to problems with the CocoaPods installation'
        UI.warn(message, actions)
      end

    end
  end
end
