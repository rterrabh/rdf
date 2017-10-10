module Pod
  class Installer
    class AggregateTargetInstaller < TargetInstaller
      def install!
        UI.message "- Installing target `#{target.name}` #{target.platform}" do
          add_target
          create_support_files_dir
          create_support_files_group
          create_xcconfig_file
          if target.requires_frameworks?
            create_info_plist_file
            create_module_map
            create_umbrella_header
          end
          create_embed_frameworks_script
          create_bridge_support_file
          create_copy_resources_script
          create_acknowledgements
          create_dummy_source
        end
      end


      private

      def target_definition
        target.target_definition
      end

      def custom_build_settings
        settings = {
          'OTHER_LDFLAGS'      => '',
          'OTHER_LIBTOOLFLAGS' => '',
          'PODS_ROOT'          => '$(SRCROOT)',
          'SKIP_INSTALL'       => 'YES',
        }
        super.merge(settings)
      end

      def create_support_files_group
        parent = project.support_files_group
        name = target.name
        dir = target.support_files_dir
        @support_files_group = parent.new_group(name, dir)
      end

      def create_xcconfig_file
        native_target.build_configurations.each do |configuration|
          path = target.xcconfig_path(configuration.name)
          gen = Generator::XCConfig::AggregateXCConfig.new(target, configuration.name)
          gen.save_as(path)
          target.xcconfigs[configuration.name] = gen.xcconfig
          xcconfig_file_ref = add_file_to_support_group(path)
          configuration.base_configuration_reference = xcconfig_file_ref
        end
      end

      def create_bridge_support_file
        if target.podfile.generate_bridge_support?
          path = target.bridge_support_path
          headers = native_target.headers_build_phase.files.map { |bf| sandbox.root + bf.file_ref.path }
          generator = Generator::BridgeSupport.new(headers)
          generator.save_as(path)
          add_file_to_support_group(path)
          @bridge_support_file = path.relative_path_from(sandbox.root)
        end
      end

      def resources_by_config
        library_targets = target.pod_targets.reject do |pod_target|
          pod_target.should_build? && pod_target.requires_frameworks?
        end
        resources_by_config = {}
        target.user_build_configurations.keys.each do |config|
          file_accessors = library_targets.select { |t| t.include_in_build_config?(target_definition, config) }.flat_map(&:file_accessors)
          resource_paths = file_accessors.flat_map { |accessor| accessor.resources.flat_map { |res| res.relative_path_from(project.path.dirname) } }
          resource_bundles = file_accessors.flat_map { |accessor| accessor.resource_bundles.keys.map { |name| "${BUILT_PRODUCTS_DIR}/#{name.shellescape}.bundle" } }
          resources_by_config[config] = (resource_paths + resource_bundles).uniq
          resources_by_config[config] << bridge_support_file if bridge_support_file
        end
        resources_by_config
      end

      def create_copy_resources_script
        path = target.copy_resources_script_path
        generator = Generator::CopyResourcesScript.new(resources_by_config, target.platform)
        generator.save_as(path)
        add_file_to_support_group(path)
      end

      def create_embed_frameworks_script
        path = target.embed_frameworks_script_path
        frameworks_by_config = {}
        target.user_build_configurations.keys.each do |config|
          relevant_pod_targets = target.pod_targets.select do |pod_target|
            pod_target.include_in_build_config?(target_definition, config)
          end
          frameworks_by_config[config] = relevant_pod_targets.flat_map do |pod_target|
            frameworks = pod_target.file_accessors.flat_map(&:vendored_dynamic_artifacts).map { |fw| "${PODS_ROOT}/#{fw.relative_path_from(sandbox.root)}" }
            frameworks << "#{target_definition.label}/#{pod_target.product_name}" if pod_target.should_build? && pod_target.requires_frameworks?
            frameworks
          end
        end
        generator = Generator::EmbedFrameworksScript.new(frameworks_by_config)
        generator.save_as(path)
        add_file_to_support_group(path)
      end

      def create_acknowledgements
        basepath = target.acknowledgements_basepath
        Generator::Acknowledgements.generators.each do |generator_class|
          path = generator_class.path_from_basepath(basepath)
          file_accessors = target.pod_targets.map(&:file_accessors).flatten
          generator = generator_class.new(file_accessors)
          generator.save_as(path)
          add_file_to_support_group(path)
        end
      end

      attr_reader :bridge_support_file

    end
  end
end
