module Pod
  class Installer
    class Analyzer
      class TargetInspector
        attr_accessor :target_definition

        attr_accessor :installation_root

        def initialize(target_definition, installation_root)
          @target_definition = target_definition
          @installation_root = installation_root
        end

        def compute_results
          project_path = compute_project_path
          user_project = Xcodeproj::Project.open(project_path)
          targets = compute_targets(user_project)

          result = TargetInspectionResult.new
          result.target_definition = target_definition
          result.project_path = project_path
          result.project_target_uuids = targets.map(&:uuid)
          result.build_configurations = compute_build_configurations(targets)
          result.platform = compute_platform(targets)
          result.archs = compute_archs(targets)
          result
        end


        private

        def compute_project_path
          if target_definition.user_project_path
            path = installation_root + target_definition.user_project_path
            path = "#{path}.xcodeproj" unless File.extname(path) == '.xcodeproj'
            path = Pathname.new(path)
            unless path.exist?
              raise Informative, 'Unable to find the Xcode project ' \
              "`#{path}` for the target `#{target_definition.label}`."
            end
          else
            xcodeprojs = installation_root.children.select { |e| e.fnmatch('*.xcodeproj') }
            if xcodeprojs.size == 1
              path = xcodeprojs.first
            else
              raise Informative, 'Could not automatically select an Xcode project. ' \
                "Specify one in your Podfile like so:\n\n" \
                "    xcodeproj 'path/to/Project.xcodeproj'\n"
            end
          end
          path
        end

        def compute_targets(user_project)
          native_targets = user_project.native_targets
          if link_with = target_definition.link_with
            targets = native_targets.select { |t| link_with.include?(t.name) }
            raise Informative, "Unable to find the targets named #{link_with.map { |x| "`#{x}`" }.to_sentence}" \
              "to link with target definition `#{target_definition.name}`" if targets.empty?
          elsif target_definition.link_with_first_target?
            targets = [native_targets.first].compact
            raise Informative, 'Unable to find a target' if targets.empty?
          else
            target = native_targets.find { |t| t.name == target_definition.name.to_s }
            targets = [target].compact
            raise Informative, "Unable to find a target named `#{target_definition.name}`" if targets.empty?
          end
          targets
        end

        def compute_build_configurations(user_targets)
          if user_targets
            user_targets.flat_map { |t| t.build_configurations.map(&:name) }.each_with_object({}) do |name, hash|
              hash[name] = name == 'Debug' ? :debug : :release
            end.merge(target_definition.build_configurations || {})
          else
            target_definition.build_configurations || {}
          end
        end

        def compute_platform(user_targets)
          return target_definition.platform if target_definition.platform
          name = nil
          deployment_target = nil

          user_targets.each do |target|
            name ||= target.platform_name
            raise Informative, 'Targets with different platforms' unless name == target.platform_name
            if !deployment_target || deployment_target > Version.new(target.deployment_target)
              deployment_target = Version.new(target.deployment_target)
            end
          end

          target_definition.set_platform(name, deployment_target)
          Platform.new(name, deployment_target)
        end

        def compute_archs(user_targets)
          user_targets.flat_map do |target|
            Array(target.common_resolved_build_setting('ARCHS'))
          end.compact.uniq.sort
        end

        def compute_recommends_frameworks(target_definition, native_targets)
          file_predicate = nil
          file_predicate = proc do |file_ref|
            if file_ref.respond_to?(:last_known_file_type)
              file_ref.last_known_file_type == 'sourcecode.swift'
            elsif file_ref.respond_to?(:files)
              file_ref.files.any?(&file_predicate)
            else
              false
            end
          end
          target_definition.platform.supports_dynamic_frameworks? || native_targets.any? do |target|
            target.source_build_phase.files.any? do |build_file|
              file_predicate.call(build_file.file_ref)
            end
          end
        end
      end
    end
  end
end
