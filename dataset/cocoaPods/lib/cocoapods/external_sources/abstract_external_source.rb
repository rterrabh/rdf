module Pod
  module ExternalSources
    class AbstractExternalSource
      attr_reader :name

      attr_reader :params

      attr_reader :podfile_path

      def initialize(name, params, podfile_path)
        @name = name
        @params = params
        @podfile_path = podfile_path
      end

      def ==(other)
        return false if other.nil?
        name == other.name && params == other.params
      end

      public


      def fetch(_sandbox)
        raise 'Abstract method'
      end

      def description
        raise 'Abstract method'
      end

      protected

      def normalized_podspec_path(declared_path)
        extension = File.extname(declared_path)
        if extension == '.podspec' || extension == '.json'
          path_with_ext = declared_path
        else
          path_with_ext = "#{declared_path}/#{name}.podspec"
        end
        podfile_dir = File.dirname(podfile_path || '')
        File.expand_path(path_with_ext, podfile_dir)
      end

      private


      def pre_download(sandbox)
        title = "Pre-downloading: `#{name}` #{description}"
        UI.titled_section(title,  :verbose_prefix => '-> ') do
          target = sandbox.pod_dir(name)
          download_result = Downloader.download(download_request, target)
          spec = download_result.spec

          raise Informative, "Unable to find a specification for '#{name}'." unless spec

          store_podspec(sandbox, spec)
          sandbox.store_pre_downloaded_pod(name)
          sandbox.store_checkout_source(name, download_result.checkout_options)
        end
      end

      def download_request
        Downloader::Request.new(
          :name => name,
          :params => params,
        )
      end

      def store_podspec(sandbox, spec, json = false)
        if spec.is_a? Pathname
          spec = Specification.from_file(spec).to_pretty_json
          json = true
        elsif spec.is_a?(String) && !json
          spec = Specification.from_string(spec, 'spec.podspec').to_pretty_json
          json = true
        elsif spec.is_a?(Specification)
          spec = spec.to_pretty_json
          json = true
        end
        sandbox.store_podspec(name, spec, true, json)
      end
    end
  end
end
