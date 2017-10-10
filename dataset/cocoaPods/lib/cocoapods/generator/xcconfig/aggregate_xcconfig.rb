module Pod
  module Generator
    module XCConfig
      class AggregateXCConfig
        attr_reader :target

        attr_reader :configuration_name

        def initialize(target, configuration_name)
          @target = target
          @configuration_name = configuration_name
        end

        attr_reader :xcconfig

        def save_as(path)
          generate.save_as(path)
        end

        def generate
          includes_static_libs = !target.requires_frameworks?
          includes_static_libs ||= pod_targets.flat_map(&:file_accessors).any? { |fa| !fa.vendored_static_artifacts.empty? }
          config = {
            'OTHER_LDFLAGS' => '$(inherited) ' + XCConfigHelper.default_ld_flags(target, includes_static_libs),
            'PODS_ROOT' => target.relative_pods_root,
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ',
          }
          @xcconfig = Xcodeproj::Config.new(config)

          @xcconfig.merge!(merged_user_target_xcconfigs)

          generate_settings_to_import_pod_targets

          XCConfigHelper.add_target_specific_settings(target, @xcconfig)

          generate_vendored_build_settings
          generate_other_ld_flags

          @xcconfig.attributes.delete('USE_HEADERMAP')

          generate_ld_runpath_search_paths if target.requires_frameworks?

          @xcconfig
        end


        private

        def generate_settings_to_import_pod_targets
          if target.requires_frameworks?
            framework_header_search_paths = pod_targets.select(&:should_build?).map do |target|
              if target.scoped?
                "$PODS_FRAMEWORK_BUILD_PATH/#{target.product_name}/Headers"
              else
                "$CONFIGURATION_BUILD_DIR/#{target.product_name}/Headers"
              end
            end
            build_settings = {
              'PODS_FRAMEWORK_BUILD_PATH' => target.scoped_configuration_build_dir,
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(framework_header_search_paths, '-iquote'),
            }
            if pod_targets.any? { |t| !t.should_build? }
              library_header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
              build_settings['HEADER_SEARCH_PATHS'] = '$(inherited) ' + XCConfigHelper.quote(library_header_search_paths)
              build_settings['OTHER_CFLAGS'] += ' ' + XCConfigHelper.quote(library_header_search_paths, '-isystem')
            end
            if pod_targets.any? { |t| t.should_build? && t.scoped? }
              build_settings['FRAMEWORK_SEARCH_PATHS'] = '"$PODS_FRAMEWORK_BUILD_PATH"'
            end
            @xcconfig.merge!(build_settings)
          else
            header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
            build_settings = {
              'HEADER_SEARCH_PATHS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths),
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths, '-isystem'),
            }
            @xcconfig.merge!(build_settings)
          end
        end

        def generate_vendored_build_settings
          pod_targets.each do |pod_target|
            unless pod_target.should_build? && pod_target.requires_frameworks?
              XCConfigHelper.add_settings_for_file_accessors_of_target(pod_target, @xcconfig)
            end
          end
        end

        def generate_other_ld_flags
          other_ld_flags = pod_targets.select(&:should_build?).map do |pod_target|
            if pod_target.requires_frameworks?
              %(-framework "#{pod_target.product_basename}")
            else
              %(-l "#{pod_target.product_basename}")
            end
          end

          @xcconfig.merge!('OTHER_LDFLAGS' => other_ld_flags.join(' '))
        end

        def generate_ld_runpath_search_paths
          ld_runpath_search_paths = ['$(inherited)']
          if target.platform.symbolic_name == :osx
            ld_runpath_search_paths << "'@executable_path/../Frameworks'"
            ld_runpath_search_paths << \
              if target.native_target.symbol_type == :unit_test_bundle
                "'@loader_path/../Frameworks'"
              else
                "'@loader_path/Frameworks'"
              end
          else
            ld_runpath_search_paths << [
              "'@executable_path/Frameworks'",
              "'@loader_path/Frameworks'",
            ]
          end
          @xcconfig.merge!('LD_RUNPATH_SEARCH_PATHS' => ld_runpath_search_paths.join(' '))
        end

        private



        def pod_targets
          target.pod_targets_for_build_configuration(configuration_name)
        end

        def user_target_xcconfig_values_by_consumer_by_key
          pod_targets.each_with_object({}) do |target, hash|
            target.spec_consumers.each do |spec_consumer|
              spec_consumer.user_target_xcconfig.each do |k, v|
                (hash[k] ||= {})[spec_consumer] = v
              end
            end
          end
        end

        def merged_user_target_xcconfigs
          settings = user_target_xcconfig_values_by_consumer_by_key
          settings.each_with_object({}) do |(key, values_by_consumer), xcconfig|
            uniq_values = values_by_consumer.values.uniq
            values_are_bools = uniq_values.all? { |v| v =~ /(yes|no)/i }
            if values_are_bools
              if uniq_values.count > 1
                UI.warn 'Can\'t merge user_target_xcconfig for pod targets: ' \
                  "#{values_by_consumer.keys.map(&:name)}. Boolean build "\
                  "setting #{key} has different values."
              else
                xcconfig[key] = uniq_values.first
              end
            elsif key =~ /S$/
              xcconfig[key] = uniq_values.join(' ')
            else
              if uniq_values.count > 1
                UI.warn 'Can\'t merge user_target_xcconfig for pod targets: ' \
                  "#{values_by_consumer.keys.map(&:name)}. Singular build "\
                  "setting #{key} has different values."
              else
                xcconfig[key] = uniq_values.first
              end
            end
          end
        end

      end
    end
  end
end
