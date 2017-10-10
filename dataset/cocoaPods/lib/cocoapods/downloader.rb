require 'cocoapods-downloader'
require 'claide/informative_error'
require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    require 'cocoapods/downloader/cache'
    require 'cocoapods/downloader/request'
    require 'cocoapods/downloader/response'

    def self.download(
      request,
      target,
      cache_path: !Config.instance.skip_download_cache && Config.instance.clean? && Config.instance.cache_root + 'Pods'
    )
      if cache_path
        cache = Cache.new(cache_path)
        result = cache.download_pod(request)
      else
        require 'cocoapods/installer/pod_source_preparer'
        result, _ = download_request(request, target)
        Installer::PodSourcePreparer.new(result.spec, result.location).prepare!
      end

      if target && result.location && target != result.location
        UI.message "Copying #{request.name} from `#{result.location}` to #{UI.path target}", '> ' do
          FileUtils.rm_rf target
          FileUtils.cp_r(result.location, target)
        end
      end
      result
    end

    def self.download_request(request, target)
      result = Response.new
      result.checkout_options = download_source(request.name, target, request.params, request.head?)
      result.location = target

      if request.released_pod?
        result.spec = request.spec
        podspecs = { request.name => request.spec }
      else
        podspecs = Sandbox::PodspecFinder.new(target).podspecs
        podspecs[request.name] = request.spec if request.spec
        podspecs.each do |name, spec|
          if request.name == name
            result.spec = spec
          end
        end
      end

      [result, podspecs]
    end

    private

    def self.download_source(name, target, params, head)
      FileUtils.rm_rf(target)
      downloader = Downloader.for_target(target, params)
      if head
        unless downloader.head_supported?
          raise Informative, "The pod '#{name}' does not " \
            "support the :head option, as it uses a #{downloader.name} " \
            'source. Remove that option to use this pod.'
        end
        downloader.download_head
      else
        downloader.download
      end
      target.mkpath

      if downloader.options_specific? && !head
        params
      else
        downloader.checkout_options
      end
    end

    public

    class DownloaderError; include CLAide::InformativeError; end

    class Base
      override_api do
        def execute_command(executable, command, raise_on_failure = false)
          Executable.execute_command(executable, command, raise_on_failure)
        rescue CLAide::InformativeError => e
          raise DownloaderError, e.message
        end

        def ui_action(message)
          UI.section(" > #{message}", '', 1) do
            yield
          end
        end

        def ui_sub_action(message)
          UI.section(" > #{message}", '', 2) do
            yield
          end
        end

        def ui_message(message)
          UI.puts message
        end
      end
    end
  end
end
