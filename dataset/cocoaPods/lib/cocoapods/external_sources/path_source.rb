module Pod
  module ExternalSources
    class PathSource < AbstractExternalSource
      def fetch(sandbox)
        title = "Fetching podspec for `#{name}` #{description}"
        UI.titled_section(title,  :verbose_prefix => '-> ') do
          podspec = podspec_path
          unless podspec.exist?
            raise Informative, "No podspec found for `#{name}` in " \
              "`#{declared_path}`"
          end
          store_podspec(sandbox, podspec, podspec.extname == '.json')
          is_absolute = absolute?(declared_path)
          sandbox.store_local_path(name, podspec.dirname, is_absolute)
          sandbox.remove_checkout_source(name)
        end
      end

      def description
        "from `#{params[:path] || params[:local]}`"
      end

      private


      def declared_path
        result = params[:path] || params[:local]
        result.to_s if result
      end

      def podspec_path
        path = Pathname(normalized_podspec_path(declared_path))
        path.exist? ? path : Pathname("#{path}.json")
      end

      def absolute?(path)
        Pathname(path).absolute? || path.to_s.start_with?('~')
      end
    end
  end
end
