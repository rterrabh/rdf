module Pod
  module Generator
    module XCConfig
      class PodXCConfig
        attr_reader :target

        def initialize(target)
          @target = target
        end

        attr_reader :xcconfig

        def save_as(path)
          generate.save_as(path)
        end

        def generate
          target_search_paths = target.build_headers.search_paths(target.platform)
          sandbox_search_paths = target.sandbox.public_headers.search_paths(target.platform)
          search_paths = target_search_paths.concat(sandbox_search_paths).uniq
          framework_search_paths = target.dependent_targets.flat_map(&:file_accessors).flat_map(&:vendored_frameworks).map { |fw| '${PODS_ROOT}/' << fw.dirname.relative_path_from(target.sandbox.root).to_s }

          config = {
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'PODS_ROOT'  => '${SRCROOT}',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(search_paths),
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'SKIP_INSTALL' => 'YES',
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ' << XCConfigHelper.quote(framework_search_paths)
          }

          @xcconfig = Xcodeproj::Config.new(config)

          if target.requires_frameworks? && target.scoped?
            build_settings = {
              'PODS_FRAMEWORK_BUILD_PATH' => target.configuration_build_dir,
              'FRAMEWORK_SEARCH_PATHS' => '"$PODS_FRAMEWORK_BUILD_PATH"',
              'CONFIGURATION_BUILD_DIR' => '$PODS_FRAMEWORK_BUILD_PATH',
            }
            @xcconfig.merge!(build_settings)
          end

          XCConfigHelper.add_settings_for_file_accessors_of_target(target, @xcconfig)
          target.file_accessors.each do |file_accessor|
            @xcconfig.merge!(file_accessor.spec_consumer.pod_target_xcconfig)
          end
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          @xcconfig
        end

      end
    end
  end
end
