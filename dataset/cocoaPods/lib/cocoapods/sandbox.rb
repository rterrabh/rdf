require 'fileutils'

module Pod
  class Sandbox
    autoload :FileAccessor,  'cocoapods/sandbox/file_accessor'
    autoload :HeadersStore,  'cocoapods/sandbox/headers_store'
    autoload :PathList,      'cocoapods/sandbox/path_list'
    autoload :PodDirCleaner, 'cocoapods/sandbox/pod_dir_cleaner'
    autoload :PodspecFinder, 'cocoapods/sandbox/podspec_finder'

    attr_reader :root

    attr_reader :public_headers

    def initialize(root)
      FileUtils.mkdir_p(root)
      @root = Pathname.new(root).realpath
      @public_headers = HeadersStore.new(self, 'Public')
      @predownloaded_pods = []
      @head_pods = []
      @checkout_sources = {}
      @development_pods = {}
      @pods_with_absolute_path = []
    end

    attr_accessor :manifest

    def manifest
      @manifest ||= begin
        Lockfile.from_file(manifest_path) if manifest_path.exist?
      end
    end

    attr_accessor :project

    def clean_pod(name)
      root_name = Specification.root_name(name)
      unless local?(root_name)
        path = pod_dir(name)
        path.rmtree if path.exist?
      end
      podspe_path = specification_path(name)
      podspe_path.rmtree if podspe_path
    end

    def prepare
      FileUtils.rm_rf(headers_root)
      FileUtils.rm_rf(target_support_files_root)

      FileUtils.mkdir_p(headers_root)
      FileUtils.mkdir_p(sources_root)
      FileUtils.mkdir_p(specifications_root)
      FileUtils.mkdir_p(target_support_files_root)
    end

    def inspect
      "#<#{self.class}> with root #{root}"
    end


    public


    def manifest_path
      root + 'Manifest.lock'
    end

    def project_path
      root + 'Pods.xcodeproj'
    end

    def target_support_files_dir(name)
      target_support_files_root + name
    end

    def pod_dir(name)
      root_name = Specification.root_name(name)
      if local?(root_name)
        Pathname.new(development_pods[root_name])
      else
        sources_root + root_name
      end
    end

    def local_path_was_absolute?(name)
      @pods_with_absolute_path.include? name
    end

    def headers_root
      root + 'Headers'
    end

    def sources_root
      root
    end

    def specifications_root
      root + 'Local Podspecs'
    end

    def target_support_files_root
      root + 'Target Support Files'
    end


    public


    def specification(name)
      if file = specification_path(name)
        original_path = development_pods[name]
        Dir.chdir(original_path || Dir.pwd) { Specification.from_file(file) }
      end
    end

    def specification_path(name)
      name = Specification.root_name(name)
      path = specifications_root + "#{name}.podspec"
      if path.exist?
        path
      else
        path = specifications_root + "#{name}.podspec.json"
        if path.exist?
          path
        end
      end
    end

    def store_podspec(name, podspec, _external_source = false, json = false)
      file_name = json ? "#{name}.podspec.json" : "#{name}.podspec"
      output_path = specifications_root + file_name
      output_path.dirname.mkpath
      if podspec.is_a?(String)
        output_path.open('w') { |f| f.puts(podspec) }
      else
        unless podspec.exist?
          raise Informative, "No podspec found for `#{name}` in #{podspec}"
        end
        FileUtils.copy(podspec, output_path)
      end

      Dir.chdir(podspec.is_a?(Pathname) ? File.dirname(podspec) : Dir.pwd) do
        spec = Specification.from_file(output_path)

        unless spec.name == name
          raise Informative, "The name of the given podspec `#{spec.name}` doesn't match the expected one `#{name}`"
        end
      end
    end


    public


    def store_pre_downloaded_pod(name)
      root_name = Specification.root_name(name)
      predownloaded_pods << root_name
    end

    attr_reader :predownloaded_pods

    def predownloaded?(name)
      root_name = Specification.root_name(name)
      predownloaded_pods.include?(root_name)
    end


    def store_head_pod(name)
      root_name = Specification.root_name(name)
      head_pods << root_name
    end

    attr_reader :head_pods

    def head_pod?(name)
      root_name = Specification.root_name(name)
      head_pods.include?(root_name)
    end


    def store_checkout_source(name, source)
      root_name = Specification.root_name(name)
      checkout_sources[root_name] = source
    end

    def remove_checkout_source(name)
      root_name = Specification.root_name(name)
      checkout_sources.delete(root_name)
    end

    attr_reader :checkout_sources


    def store_local_path(name, path, was_absolute = false)
      root_name = Specification.root_name(name)
      development_pods[root_name] = path.to_s
      @pods_with_absolute_path << root_name if was_absolute
    end

    attr_reader :development_pods

    def local?(name)
      root_name = Specification.root_name(name)
      !development_pods[root_name].nil?
    end

  end
end
