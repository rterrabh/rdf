module Pod
  module Generator
    module XCConfig
      module XCConfigHelper
        def self.quote(strings, prefix = nil)
          prefix = "#{prefix} " if prefix
          strings.sort.map { |s| %W(          #{prefix}"#{s}"          ) }.join(' ')
        end

        def self.default_ld_flags(target, includes_static_libraries = false)
          ld_flags = ''
          ld_flags << '-ObjC' if includes_static_libraries
          if target.podfile.set_arc_compatibility_flag? &&
              target.spec_consumers.any?(&:requires_arc?)
            ld_flags << ' -fobjc-arc'
          end
          ld_flags.strip
        end

        def self.add_settings_for_file_accessors_of_target(target, xcconfig)
          target.file_accessors.each do |file_accessor|
            XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, xcconfig)
            file_accessor.vendored_frameworks.each do |vendored_framework|
              XCConfigHelper.add_framework_build_settings(vendored_framework, xcconfig, target.sandbox.root)
            end
            file_accessor.vendored_libraries.each do |vendored_library|
              XCConfigHelper.add_library_build_settings(vendored_library, xcconfig, target.sandbox.root)
            end
          end
        end

        def self.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
          xcconfig.libraries.merge(consumer.libraries)
          xcconfig.frameworks.merge(consumer.frameworks)
          xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
          add_developers_frameworks_if_needed(xcconfig, consumer.platform_name)
        end

        def self.add_framework_build_settings(framework_path, xcconfig, sandbox_root)
          name = File.basename(framework_path, '.framework')
          dirname = '$(PODS_ROOT)/' + framework_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'OTHER_LDFLAGS' => "-framework #{name}",
            'FRAMEWORK_SEARCH_PATHS' => quote([dirname]),
          }
          xcconfig.merge!(build_settings)
        end

        def self.add_library_build_settings(library_path, xcconfig, sandbox_root)
          name = File.basename(library_path, '.a').sub(/\Alib/, '')
          dirname = '$(PODS_ROOT)/' + library_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'OTHER_LDFLAGS' => "-l#{name}",
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ' + quote([dirname]),
          }
          xcconfig.merge!(build_settings)
        end

        def self.add_code_signing_settings(target, xcconfig)
          build_settings = {}
          if target.platform.to_sym == :osx
            build_settings['CODE_SIGN_IDENTITY'] = ''
          end
          xcconfig.merge!(build_settings)
        end

        def self.add_target_specific_settings(target, xcconfig)
          if target.requires_frameworks?
            add_code_signing_settings(target, xcconfig)
          end
          add_language_specific_settings(target, xcconfig)
        end

        def self.add_language_specific_settings(target, xcconfig)
          if target.uses_swift?
            build_settings = {
              'OTHER_SWIFT_FLAGS' => '$(inherited) ' + quote(%w(-D COCOAPODS)),
            }
            xcconfig.merge!(build_settings)
          end
        end

        def self.add_developers_frameworks_if_needed(xcconfig, platform)
          matched_frameworks = xcconfig.frameworks & %w(XCTest SenTestingKit)
          unless matched_frameworks.empty?
            search_paths = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] ||= ''
            search_paths_to_add = []
            search_paths_to_add << '$(inherited)'
            if platform == :ios || platform == :watchos
              search_paths_to_add << '"$(SDKROOT)/Developer/Library/Frameworks"'
            else
              search_paths_to_add << '"$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
            end
            frameworks_path = '"$(PLATFORM_DIR)/Developer/Library/Frameworks"'
            search_paths_to_add << frameworks_path
            search_paths_to_add.each do |search_path|
              unless search_paths.include?(search_path)
                search_paths << ' ' unless search_paths.empty?
                search_paths << search_path
              end
            end
            search_paths
          end
        end

      end
    end
  end
end
