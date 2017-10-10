module Pod
  module ExternalSources
    class DownloaderSource < AbstractExternalSource
      def fetch(sandbox)
        pre_download(sandbox)
      end

      def description
        strategy = Downloader.strategy_from_options(params)
        options = params.dup
        url = options.delete(strategy)
        result = "from `#{url}`"
        options.each do |key, value|
          result << ", #{key} `#{value}`"
        end
        result
      end
    end
  end
end
