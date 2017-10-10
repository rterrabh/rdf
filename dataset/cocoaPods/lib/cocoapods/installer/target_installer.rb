module Pod
  class Installer
    class TargetInstaller
      attr_reader :sandbox

      attr_reader :target

      def initialize(sandbox, target)
        @sandbox = sandbox
        @target = target
      end

      private



      def add_target
        product_type = target.product_type
        name = target.label
        platform = target.platform.name
        deployment_target = target.platform.deployment_target.to_s
        language = target.uses_swift? ? :swift : :objc
        @native_target = project.new_target(product_type, name, platform, deployment_target, nil, language)

        product_name = target.product_name
        product = @native_target.product_reference
        product.name = product_name
        product.path = product_name

        target.user_build_configurations.each do |bc_name, type|
          @native_target.add_build_configuration(bc_name, type)
        end

        @native_target.build_configurations.each do |configuration|
          configuration.build_settings.merge!(custom_build_settings)
        end

        target.native_target = @native_target
      end

      def custom_build_settings
        settings = {}

        unless target.archs.empty?
          settings['ARCHS'] = target.archs
        end

        if target.requires_frameworks?
          settings['PRODUCT_NAME'] = target.product_module_name
        else
          settings.merge!('OTHER_LDFLAGS' => '', 'OTHER_LIBTOOLFLAGS' => '')
        end

        settings
      end

      def create_support_files_dir
        target.support_files_dir.mkdir
      end

      def create_info_plist_file
        path = target.info_plist_path
        UI.message "- Generating Info.plist file at #{UI.path(path)}" do
          generator = Generator::InfoPlistFile.new(target)
          generator.save_as(path)
          add_file_to_support_group(path)

          native_target.build_configurations.each do |c|
            relative_path = path.relative_path_from(sandbox.root)
            c.build_settings['INFOPLIST_FILE'] = relative_path.to_s
          end
        end
      end

      def create_module_map
        path = target.module_map_path
        UI.message "- Generating module map file at #{UI.path(path)}" do
          generator = Generator::ModuleMap.new(target)
          yield generator if block_given?
          generator.save_as(path)
          add_file_to_support_group(path)

          native_target.build_configurations.each do |c|
            relative_path = path.relative_path_from(sandbox.root)
            c.build_settings['MODULEMAP_FILE'] = relative_path.to_s
          end
        end
      end

      def create_umbrella_header
        path = target.umbrella_header_path
        UI.message "- Generating umbrella header at #{UI.path(path)}" do
          generator = Generator::UmbrellaHeader.new(target)
          yield generator if block_given?
          generator.save_as(path)

          file_ref = add_file_to_support_group(path)
          native_target.add_file_references([file_ref])

          build_file = native_target.headers_build_phase.build_file(file_ref)
          build_file.settings ||= {}
          build_file.settings['ATTRIBUTES'] = ['Public']
        end
      end

      def create_dummy_source
        path = target.dummy_source_path
        generator = Generator::DummySource.new(target.label)
        generator.save_as(path)
        file_reference = add_file_to_support_group(path)
        native_target.source_build_phase.add_file_reference(file_reference)
      end

      attr_reader :native_target

      private



      def project
        sandbox.project
      end

      attr_reader :support_files_group

      def add_file_to_support_group(path)
        support_files_group.new_file(path)
      end

    end
  end
end
