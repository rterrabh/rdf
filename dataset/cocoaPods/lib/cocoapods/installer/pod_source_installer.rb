require 'active_support/core_ext/string/strip'

module Pod
  class Installer
    class PodSourceInstaller
      attr_reader :sandbox

      attr_reader :specs_by_platform

      def initialize(sandbox, specs_by_platform)
        @sandbox = sandbox
        @specs_by_platform = specs_by_platform
      end

      def inspect
        "<#{self.class} sandbox=#{sandbox.root} pod=#{root_spec.name}"
      end

      def name
        root_spec.name
      end


      public


      def install!
        download_source unless predownloaded? || local?
        PodSourcePreparer.new(root_spec, root).prepare! if local?
      end

      def clean!
        clean_installation unless local?
      end

      def lock_files!(file_accessors)
        return if local?
        each_source_file(file_accessors) do |source_file|
          FileUtils.chmod('u-w', source_file)
        end
      end

      def unlock_files!(file_accessors)
        return if local?
        each_source_file(file_accessors) do |source_file|
          FileUtils.chmod('u+w', source_file)
        end
      end

      attr_reader :specific_source


      private


      def download_source
        download_result = Downloader.download(download_request, root)

        if (@specific_source = download_result.checkout_options) && specific_source != root_spec.source
          sandbox.store_checkout_source(root_spec.name, specific_source)
        end
      end

      def download_request
        Downloader::Request.new(
          :spec => root_spec,
          :released => released?,
          :head => head_pod?,
        )
      end

      def clean_installation
        cleaner = Sandbox::PodDirCleaner.new(root, specs_by_platform)
        cleaner.clean!
      end


      private


      def specs
        specs_by_platform.values.flatten
      end

      def root_spec
        specs.first.root
      end

      def root
        sandbox.pod_dir(root_spec.name)
      end

      def predownloaded?
        sandbox.predownloaded_pods.include?(root_spec.name)
      end

      def local?
        sandbox.local?(root_spec.name)
      end

      def head_pod?
        sandbox.head_pod?(root_spec.name)
      end

      def released?
        !local? && !head_pod? && !predownloaded? && sandbox.specification(root_spec.name) != root_spec
      end

      def each_source_file(file_accessors, &blk)
        file_accessors.each do |file_accessor|
          file_accessor.source_files.each do |source_file|
            next unless source_file.exist?
            blk[source_file]
          end
        end
      end

    end
  end
end
