module Pod
  class Installer
    class PodTargetInstaller < TargetInstaller
      def install!
        unless target.should_build?
          add_resources_bundle_targets
          return
        end

        UI.message "- Installing target `#{target.name}` #{target.platform}" do
          add_target
          create_support_files_dir
          add_resources_bundle_targets
          add_files_to_build_phases
          create_xcconfig_file
          if target.requires_frameworks?
            create_info_plist_file
            create_module_map do |generator|
              generator.private_headers += target.file_accessors.flat_map(&:private_headers).map(&:basename)
            end
            create_umbrella_header do |generator|
              generator.imports += target.file_accessors.flat_map(&:public_headers).map(&:basename)
            end
          end
          create_prefix_header
          create_dummy_source
        end
      end

      private

      def custom_build_settings
        settings = super
        if target.requires_frameworks?
          version = target.root_spec.version
          project_version = [version.major, version.minor, version.patch].join('.')
          compatibility_version = version.major
          compatibility_version = project_version if compatibility_version < 1
          settings['CURRENT_PROJECT_VERSION'] = project_version
          settings['DYLIB_COMPATIBILITY_VERSION'] = compatibility_version.to_s
          settings['DYLIB_CURRENT_VERSION'] = '$(CURRENT_PROJECT_VERSION)'
        end
        settings
      end


      SOURCE_FILE_EXTENSIONS = Sandbox::FileAccessor::SOURCE_FILE_EXTENSIONS

      def add_files_to_build_phases
        target.file_accessors.each do |file_accessor|
          consumer = file_accessor.spec_consumer

          headers = file_accessor.headers
          public_headers = file_accessor.public_headers
          private_headers = file_accessor.private_headers
          other_source_files = file_accessor.source_files.reject { |sf| SOURCE_FILE_EXTENSIONS.include?(sf.extname) }

          {
            true => file_accessor.arc_source_files,
            false => file_accessor.non_arc_source_files,
          }.each do |arc, files|
            files = files - headers - other_source_files
            flags = compiler_flags_for_consumer(consumer, arc)
            regular_file_refs = files.map { |sf| project.reference_for_path(sf) }
            native_target.add_file_references(regular_file_refs, flags)
          end

          header_file_refs = headers.map { |sf| project.reference_for_path(sf) }
          native_target.add_file_references(header_file_refs) do |build_file|
            build_file.settings ||= {}
            if public_headers.include?(build_file.file_ref.real_path)
              build_file.settings['ATTRIBUTES'] = ['Public']
            elsif private_headers.include?(build_file.file_ref.real_path)
              build_file.settings['ATTRIBUTES'] = ['Private']
            else
              build_file.settings['ATTRIBUTES'] = ['Project']
            end
          end

          other_file_refs = other_source_files.map { |sf| project.reference_for_path(sf) }
          native_target.add_file_references(other_file_refs, nil)

          next unless target.requires_frameworks?

          resource_refs = file_accessor.resources.flatten.map do |res|
            project.reference_for_path(res)
          end

          native_target.add_resources(resource_refs)
        end
      end

      def add_resources_bundle_targets
        target.file_accessors.each do |file_accessor|
          file_accessor.resource_bundles.each do |bundle_name, paths|
            file_references = paths.map { |sf| project.reference_for_path(sf) }
            label = target.resources_bundle_target_label(bundle_name)
            bundle_target = project.new_resources_bundle(label, file_accessor.spec_consumer.platform_name)
            bundle_target.product_reference.tap do |bundle_product|
              bundle_file_name = "#{bundle_name}.bundle"
              bundle_product.name = bundle_file_name
              bundle_product.path = bundle_file_name
            end
            bundle_target.add_resources(file_references)

            target.user_build_configurations.each do |bc_name, type|
              bundle_target.add_build_configuration(bc_name, type)
            end

            target.resource_bundle_targets << bundle_target

            if target.should_build?
              native_target.add_dependency(bundle_target)
              if target.requires_frameworks?
                native_target.add_resources([bundle_target.product_reference])
              end
            end

            bundle_target.build_configurations.each do |c|
              c.build_settings['PRODUCT_NAME'] = bundle_name
              if target.requires_frameworks? && target.scoped?
                c.build_settings['CONFIGURATION_BUILD_DIR'] = target.configuration_build_dir
              end
            end
          end
        end
      end

      def create_xcconfig_file
        path = target.xcconfig_path
        xcconfig_gen = Generator::XCConfig::PodXCConfig.new(target)
        xcconfig_gen.save_as(path)
        xcconfig_file_ref = add_file_to_support_group(path)

        native_target.build_configurations.each do |c|
          c.base_configuration_reference = xcconfig_file_ref
        end

        target.resource_bundle_targets.each do |rsrc_target|
          rsrc_target.build_configurations.each do |rsrc_bc|
            rsrc_bc.base_configuration_reference = xcconfig_file_ref
          end
        end
      end

      def create_prefix_header
        path = target.prefix_header_path
        generator = Generator::PrefixHeader.new(target.file_accessors, target.platform)
        generator.save_as(path)
        add_file_to_support_group(path)

        native_target.build_configurations.each do |c|
          relative_path = path.relative_path_from(project.path.dirname)
          c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
        end
      end

      ENABLE_OBJECT_USE_OBJC_FROM = {
        :ios => Version.new('6'),
        :osx => Version.new('10.8'),
        :watchos => Version.new('2.0'),
      }

      def compiler_flags_for_consumer(consumer, arc)
        flags = consumer.compiler_flags.dup
        if !arc
          flags << '-fno-objc-arc'
        else
          platform_name = consumer.platform_name
          spec_deployment_target = consumer.spec.deployment_target(platform_name)
          if spec_deployment_target.nil? || Version.new(spec_deployment_target) < ENABLE_OBJECT_USE_OBJC_FROM[platform_name]
            flags << '-DOS_OBJECT_USE_OBJC=0'
          end
        end
        if target.inhibit_warnings?
          flags << '-w -Xanalyzer -analyzer-disable-all-checks'
        end
        flags * ' '
      end

      def add_file_to_support_group(path)
        pod_name = target.pod_name
        dir = target.support_files_dir
        group = project.pod_support_files_group(pod_name, dir)
        group.new_file(path)
      end

      def create_module_map
        return super unless custom_module_map
        path = target.module_map_path
        UI.message "- Copying module map file to #{UI.path(path)}" do
          FileUtils.cp(custom_module_map, path)
          add_file_to_support_group(path)

          native_target.build_configurations.each do |c|
            relative_path = path.relative_path_from(sandbox.root)
            c.build_settings['MODULEMAP_FILE'] = relative_path.to_s
          end
        end
      end

      def create_umbrella_header
        return super unless custom_module_map
      end

      def custom_module_map
        @custom_module_map ||= target.file_accessors.first.module_map
      end

    end
  end
end
