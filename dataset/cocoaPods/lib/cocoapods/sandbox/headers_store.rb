module Pod
  class Sandbox
    class HeadersStore
      def root
        sandbox.headers_root + @relative_path
      end

      attr_reader :sandbox

      def initialize(sandbox, relative_path)
        @sandbox       = sandbox
        @relative_path = relative_path
        @search_paths  = []
      end

      def search_paths(platform)
        platform_search_paths = @search_paths.select { |entry| entry[:platform] == platform }

        headers_dir = root.relative_path_from(sandbox.root).dirname
        ["${PODS_ROOT}/#{headers_dir}/#{@relative_path}"] + platform_search_paths.uniq.map { |entry| "${PODS_ROOT}/#{headers_dir}/#{entry[:path]}" }
      end

      def implode!
        root.rmtree if root.exist?
      end


      public


      def add_files(namespace, relative_header_paths)
        relative_header_paths.map do |relative_header_path|
          add_file(namespace, relative_header_path, relative_header_path.basename)
        end
      end

      def add_file(namespace, relative_header_path, final_name)
        namespaced_path = root + namespace
        namespaced_path.mkpath unless File.exist?(namespaced_path)

        absolute_source = (sandbox.root + relative_header_path)
        source = absolute_source.relative_path_from(namespaced_path)
        Dir.chdir(namespaced_path) do
          FileUtils.ln_sf(source, final_name)
        end
        namespaced_path + relative_header_path.basename
      end

      def add_search_path(path, platform)
        @search_paths << { :platform => platform, :path => (Pathname.new(@relative_path) + path) }
      end

    end
  end
end
