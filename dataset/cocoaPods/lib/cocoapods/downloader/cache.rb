require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    class Cache
      attr_reader :root

      def initialize(root)
        @root = Pathname(root)
        ensure_matching_version
      end

      def download_pod(request)
        cached_pod(request) || uncached_pod(request)
      rescue Informative
        raise
      rescue
        UI.notice("Error installing #{request.name}")
        raise
      end

      def cache_descriptors_per_pod
        specs_dir = root + 'Specs'
        release_specs_dir = specs_dir + 'Release'
        return {} unless specs_dir.exist?

        spec_paths = specs_dir.find.select { |f| f.fnmatch('*.podspec.json') }
        spec_paths.reduce({}) do |hash, spec_path|
          spec = Specification.from_file(spec_path)
          hash[spec.name] ||= []
          is_release = spec_path.to_s.start_with?(release_specs_dir.to_s)
          request = Downloader::Request.new(:spec => spec, :released => is_release)
          hash[spec.name] << {
            :spec_file => spec_path,
            :name => spec.name,
            :version => spec.version,
            :release => is_release,
            :slug => root + request.slug,
          }
          hash
        end
      end

      private

      def ensure_matching_version
        version_file = root + 'VERSION'
        version = version_file.read.strip if version_file.file?

        root.rmtree if version != Pod::VERSION && root.exist?
        root.mkpath

        version_file.open('w') { |f| f << Pod::VERSION }
      end

      def path_for_pod(request, slug_opts = {})
        root + request.slug(slug_opts)
      end

      def path_for_spec(request, slug_opts = {})
        path = root + 'Specs' + request.slug(slug_opts)
        path.sub_ext('.podspec.json')
      end

      def cached_pod(request)
        cached_spec = cached_spec(request)
        path = path_for_pod(request)
        return unless cached_spec && path.directory?
        spec = request.spec || cached_spec
        Response.new(path, spec, request.params)
      end

      def cached_spec(request)
        path = path_for_spec(request)
        path.file? && Specification.from_file(path)
      rescue JSON::ParserError
        nil
      end

      def uncached_pod(request)
        in_tmpdir do |target|
          result, podspecs = download(request, target)
          result.location = nil

          podspecs.each do |name, spec|
            destination = path_for_pod(request, :name => name, :params => result.checkout_options)
            copy_and_clean(target, destination, spec)
            write_spec(spec, path_for_spec(request, :name => name, :params => result.checkout_options))
            if request.name == name
              result.location = destination
            end
          end

          result
        end
      end

      def download(request, target)
        Downloader.download_request(request, target)
      end

      def in_tmpdir(&blk)
        tmpdir = Pathname(Dir.mktmpdir)
        blk.call(tmpdir)
      ensure
        FileUtils.remove_entry(tmpdir) if tmpdir && tmpdir.exist?
      end

      def copy_and_clean(source, destination, spec)
        specs_by_platform = group_subspecs_by_platform(spec)
        destination.parent.mkpath
        FileUtils.rm_rf(destination)
        FileUtils.cp_r(source, destination)
        Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
        Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
      end

      def group_subspecs_by_platform(spec)
        specs_by_platform = {}
        [spec, *spec.recursive_subspecs].each do |ss|
          ss.available_platforms.each do |platform|
            specs_by_platform[platform] ||= []
            specs_by_platform[platform] << ss
          end
        end
        specs_by_platform
      end

      def write_spec(spec, path)
        path.dirname.mkpath
        path.open('w') { |f| f.write spec.to_pretty_json }
      end
    end
  end
end
