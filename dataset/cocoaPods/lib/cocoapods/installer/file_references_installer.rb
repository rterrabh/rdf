module Pod
  class Installer
    class FileReferencesInstaller
      attr_reader :sandbox

      attr_reader :pod_targets

      attr_reader :pods_project

      def initialize(sandbox, pod_targets, pods_project)
        @sandbox = sandbox
        @pod_targets = pod_targets
        @pods_project = pods_project
      end

      def install!
        refresh_file_accessors
        add_source_files_references
        add_frameworks_bundles
        add_vendored_libraries
        add_resources
        link_headers
      end


      private


      def refresh_file_accessors
        file_accessors.each do |fa|
          fa.path_list.read_file_system
        end
      end

      def add_source_files_references
        UI.message '- Adding source files to Pods project' do
          add_file_accessors_paths_to_pods_group(:source_files, nil, true)
        end
      end

      def add_frameworks_bundles
        UI.message '- Adding frameworks to Pods project' do
          add_file_accessors_paths_to_pods_group(:vendored_frameworks, :frameworks)
        end
      end

      def add_vendored_libraries
        UI.message '- Adding libraries to Pods project' do
          add_file_accessors_paths_to_pods_group(:vendored_libraries, :frameworks)
        end
      end

      def add_resources
        UI.message '- Adding resources to Pods project' do
          add_file_accessors_paths_to_pods_group(:resources, :resources, true)
          add_file_accessors_paths_to_pods_group(:resource_bundle_files, :resources, true)
        end
      end

      def link_headers
        UI.message '- Linking headers' do
          pod_targets.each do |pod_target|
            pod_target.file_accessors.each do |file_accessor|
              framework_exp = /\.framework\//
              headers_sandbox = Pathname.new(file_accessor.spec.root.name)
              pod_target.build_headers.add_search_path(headers_sandbox, pod_target.platform)

              unless pod_target.requires_frameworks? && pod_target.should_build?
                sandbox.public_headers.add_search_path(headers_sandbox, pod_target.platform)
              end

              header_mappings(headers_sandbox, file_accessor, file_accessor.headers).each do |namespaced_path, files|
                pod_target.build_headers.add_files(namespaced_path, files.reject { |f| f.to_path =~ framework_exp })
              end

              unless pod_target.requires_frameworks? && pod_target.should_build?
                header_mappings(headers_sandbox, file_accessor, file_accessor.public_headers).each do |namespaced_path, files|
                  sandbox.public_headers.add_files(namespaced_path, files.reject { |f| f.to_path =~ framework_exp })
                end
              end

              vendored_frameworks_header_mappings(headers_sandbox, file_accessor).each do |namespaced_path, files|
                sandbox.public_headers.add_files(namespaced_path, files)
              end
            end
          end
        end
      end


      private


      def file_accessors
        @file_accessors ||= pod_targets.map(&:file_accessors).flatten.compact
      end

      def add_file_accessors_paths_to_pods_group(file_accessor_key, group_key = nil, reflect_file_system_structure_for_development = false)
        file_accessors.each do |file_accessor|
          pod_name = file_accessor.spec.name
          local = sandbox.local?(pod_name)
          #nodyna <send-2702> <SD MODERATE (change-prone variable)>
          paths = file_accessor.send(file_accessor_key)
          paths.each do |path|
            group = pods_project.group_for_spec(file_accessor.spec.name, group_key)
            pods_project.add_file_reference(path, group, local && reflect_file_system_structure_for_development)
          end
        end
      end

      def header_mappings(headers_sandbox, file_accessor, headers)
        consumer = file_accessor.spec_consumer
        dir = headers_sandbox
        dir += consumer.header_dir if consumer.header_dir

        mappings = {}
        headers.each do |header|
          sub_dir = dir
          if consumer.header_mappings_dir
            header_mappings_dir = file_accessor.path_list.root + consumer.header_mappings_dir
            relative_path = header.relative_path_from(header_mappings_dir)
            sub_dir += relative_path.dirname
          end
          mappings[sub_dir] ||= []
          mappings[sub_dir] << header
        end
        mappings
      end

      def vendored_frameworks_header_mappings(headers_sandbox, file_accessor)
        mappings = {}
        file_accessor.vendored_frameworks.each do |framework|
          headers_dir = Sandbox::FileAccessor.vendored_frameworks_headers_dir(framework)
          headers = Sandbox::FileAccessor.vendored_frameworks_headers(framework)
          framework_name = framework.basename(framework.extname)
          dir = headers_sandbox + framework_name
          headers.each do |header|
            relative_path = header.relative_path_from(headers_dir)
            sub_dir = dir + relative_path.dirname
            mappings[sub_dir] ||= []
            mappings[sub_dir] << header
          end
        end
        mappings
      end

    end
  end
end
