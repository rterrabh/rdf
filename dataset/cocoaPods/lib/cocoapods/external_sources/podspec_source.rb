module Pod
  module ExternalSources
    class PodspecSource < AbstractExternalSource
      def fetch(sandbox)
        title = "Fetching podspec for `#{name}` #{description}"
        UI.titled_section(title,  :verbose_prefix => '-> ') do
          podspec_path = Pathname(podspec_uri)
          is_json = podspec_path.extname == '.json'
          if podspec_path.exist?
            store_podspec(sandbox, podspec_path, is_json)
          else
            require 'open-uri'
            begin
              open(podspec_uri) { |io| store_podspec(sandbox, io.read, is_json) }
            rescue OpenURI::HTTPError => e
              status = e.io.status.join(' ')
              raise Informative, "Failed to fetch podspec for `#{name}` at `#{podspec_uri}`.\n Error: #{status}"
            end
          end
        end
      end

      def description
        "from `#{params[:podspec]}`"
      end

      private


      def podspec_uri
        declared_path = params[:podspec].to_s
        if declared_path.match(%r{^.+://})
          declared_path
        else
          normalized_podspec_path(declared_path)
        end
      end
    end
  end
end
