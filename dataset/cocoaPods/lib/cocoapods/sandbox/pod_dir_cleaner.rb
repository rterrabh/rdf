module Pod
  class Sandbox
    class PodDirCleaner
      attr_reader :root
      attr_reader :specs_by_platform

      def initialize(root, specs_by_platform)
        @root = root
        @specs_by_platform = specs_by_platform
      end

      def clean!
        clean_paths.each { |path| FileUtils.rm_rf(path) } if root.exist?
      end

      private

      def file_accessors
        @file_accessors ||= specs_by_platform.flat_map do |platform, specs|
          specs.flat_map { |spec| Sandbox::FileAccessor.new(path_list, spec.consumer(platform)) }
        end
      end

      def path_list
        @path_list ||= Sandbox::PathList.new(root)
      end

      def clean_paths
        cached_used = used_files
        glob_options = File::FNM_DOTMATCH | File::FNM_CASEFOLD
        files = Pathname.glob(root + '**/*', glob_options).map(&:to_s)

        files.reject do |candidate|
          candidate = candidate.downcase
          candidate.end_with?('.', '..') || cached_used.any? do |path|
            path = path.downcase
            path.include?(candidate) || candidate.include?(path)
          end
        end
      end

      def used_files
        files = [
          file_accessors.map(&:vendored_frameworks),
          file_accessors.map(&:vendored_libraries),
          file_accessors.map(&:resource_bundle_files),
          file_accessors.map(&:license),
          file_accessors.map(&:prefix_header),
          file_accessors.map(&:preserve_paths),
          file_accessors.map(&:readme),
          file_accessors.map(&:resources),
          file_accessors.map(&:source_files),
          file_accessors.map(&:module_map),
        ]

        files.flatten.compact.map(&:to_s).uniq
      end
    end
  end
end
