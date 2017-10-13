module Pod
  class Sandbox
    class FileAccessor
      HEADER_EXTENSIONS = Xcodeproj::Constants::HEADER_FILES_EXTENSIONS
      SOURCE_FILE_EXTENSIONS = (%w(.m .mm .c .cc .cxx .cpp .c++ .swift) + HEADER_EXTENSIONS).uniq.freeze

      GLOB_PATTERNS = {
        :readme              => 'readme{*,.*}'.freeze,
        :license             => 'licen{c,s}e{*,.*}'.freeze,
        :source_files        => "*{#{SOURCE_FILE_EXTENSIONS.join(',')}}".freeze,
        :public_header_files => "*{#{HEADER_EXTENSIONS.join(',')}}".freeze,
      }.freeze

      attr_reader :path_list

      attr_reader :spec_consumer

      def initialize(path_list, spec_consumer)
        if path_list.is_a?(PathList)
          @path_list = path_list
        else
          @path_list = PathList.new(path_list)
        end
        @spec_consumer = spec_consumer

        unless @spec_consumer
          raise Informative, 'Attempt to initialize File Accessor without a specification consumer.'
        end
      end

      def root
        path_list.root if path_list
      end

      def spec
        spec_consumer.spec
      end

      def platform_name
        spec_consumer.platform_name
      end

      def inspect
        "<#{self.class} spec=#{spec.name} platform=#{platform_name} root=#{root}>"
      end


      public


      def source_files
        paths_for_attribute(:source_files)
      end

      def arc_source_files
        case spec_consumer.requires_arc
        when TrueClass
          source_files
        when FalseClass
          []
        else
          paths_for_attribute(:requires_arc) & source_files
        end
      end

      def non_arc_source_files
        source_files - arc_source_files
      end

      def headers
        extensions = HEADER_EXTENSIONS
        source_files.select { |f| extensions.include?(f.extname) }
      end

      def public_headers(include_frameworks = false)
        public_headers = public_header_files
        private_headers = private_header_files
        if public_headers.nil? || public_headers.empty?
          header_files = headers
        else
          header_files = public_headers
        end
        header_files += vendored_frameworks_headers if include_frameworks
        header_files - private_headers
      end

      def private_headers
        private_header_files
      end

      def resources
        paths_for_attribute(:resources, true)
      end

      def preserve_paths
        paths_for_attribute(:preserve_paths, true)
      end

      def vendored_frameworks
        paths_for_attribute(:vendored_frameworks, true)
      end

      def vendored_dynamic_frameworks
        vendored_frameworks.select do |framework|
          dynamic_binary?(framework + framework.basename('.*'))
        end
      end

      def vendored_static_frameworks
        vendored_frameworks - vendored_dynamic_frameworks
      end

      def self.vendored_frameworks_headers_dir(framework)
        dir = framework + 'Headers'
        dir.directory? ? dir.realpath : dir
      end

      def self.vendored_frameworks_headers(framework)
        headers_dir = vendored_frameworks_headers_dir(framework)
        Pathname.glob(headers_dir + '**/' + GLOB_PATTERNS[:public_header_files])
      end

      def vendored_frameworks_headers
        vendored_frameworks.map do |framework|
          self.class.vendored_frameworks_headers(framework)
        end.flatten.uniq
      end

      def vendored_libraries
        paths_for_attribute(:vendored_libraries)
      end

      def vendored_dynamic_libraries
        vendored_libraries.select do |library|
          dynamic_binary?(library)
        end
      end

      def vendored_static_libraries
        vendored_libraries - vendored_dynamic_libraries
      end

      def vendored_dynamic_artifacts
        vendored_dynamic_libraries + vendored_dynamic_frameworks
      end

      def vendored_static_artifacts
        vendored_static_libraries + vendored_static_frameworks
      end

      def resource_bundles
        result = {}
        spec_consumer.resource_bundles.each do |name, file_patterns|
          paths = expanded_paths(file_patterns,
                                 :exclude_patterns => spec_consumer.exclude_files,
                                 :include_dirs => true)
          result[name] = paths
        end
        result
      end

      def resource_bundle_files
        resource_bundles.values.flatten
      end

      def prefix_header
        if spec_consumer.prefix_header_file
          path_list.root + spec_consumer.prefix_header_file
        end
      end

      def readme
        path_list.glob([GLOB_PATTERNS[:readme]]).first
      end

      def license
        if spec_consumer.spec.root.license[:file]
          path_list.root + spec_consumer.spec.root.license[:file]
        else
          path_list.glob([GLOB_PATTERNS[:license]]).first
        end
      end

      def module_map
        if module_map = spec_consumer.spec.root.module_map
          path_list.root + module_map
        end
      end


      private


      def public_header_files
        paths_for_attribute(:public_header_files)
      end

      def private_header_files
        paths_for_attribute(:private_header_files)
      end


      private


      def paths_for_attribute(attribute, include_dirs = false)
        #nodyna <send-2703> <SD MODERATE (change-prone variable)>
        file_patterns = spec_consumer.send(attribute)
        options = {
          :exclude_patterns => spec_consumer.exclude_files,
          :dir_pattern => GLOB_PATTERNS[attribute],
          :include_dirs => include_dirs,
        }
        expanded_paths(file_patterns, options)
      end

      def expanded_paths(patterns, options = {})
        return [] if patterns.empty?
        result = []
        result << path_list.glob(patterns, options)
        result.flatten.compact.uniq
      end

      def dynamic_binary?(binary)
        return unless binary.file?
        output, status = Executable.capture_command('file', [binary], :capture => :out)
        status.success? && output =~ /dynamically linked/
      end

    end
  end
end
