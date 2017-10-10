require 'thread'

module Sass
  module Plugin
    class StalenessChecker
      @dependencies_cache = {}
      @dependency_cache_mutex = Mutex.new

      class << self
        attr_accessor :dependencies_cache
        attr_reader :dependency_cache_mutex
      end

      def initialize(options)
        @actively_checking = Set.new

        @mtimes, @dependencies_stale, @parse_trees = {}, {}, {}
        @options = Sass::Engine.normalize_options(options)
      end

      def stylesheet_needs_update?(css_file, template_file, importer = nil)
        template_file = File.expand_path(template_file)
        begin
          css_mtime = File.mtime(css_file)
        rescue Errno::ENOENT
          return true
        end
        stylesheet_modified_since?(template_file, css_mtime, importer)
      end

      def stylesheet_modified_since?(template_file, mtime, importer = nil)
        importer ||= @options[:filesystem_importer].new(".")
        dependency_updated?(mtime).call(template_file, importer)
      end

      def self.stylesheet_needs_update?(css_file, template_file, importer = nil)
        new(Plugin.engine_options).stylesheet_needs_update?(css_file, template_file, importer)
      end

      def self.stylesheet_modified_since?(template_file, mtime, importer = nil)
        new(Plugin.engine_options).stylesheet_modified_since?(template_file, mtime, importer)
      end

      private

      def dependencies_stale?(uri, importer, css_mtime)
        timestamps = @dependencies_stale[[uri, importer]] ||= {}
        timestamps.each_pair do |checked_css_mtime, is_stale|
          if checked_css_mtime <= css_mtime && !is_stale
            return false
          elsif checked_css_mtime > css_mtime && is_stale
            return true
          end
        end
        timestamps[css_mtime] = dependencies(uri, importer).any?(&dependency_updated?(css_mtime))
      rescue Sass::SyntaxError
        true
      end

      def mtime(uri, importer)
        @mtimes[[uri, importer]] ||=
          begin
            mtime = importer.mtime(uri, @options)
            if mtime.nil?
              with_dependency_cache {|cache| cache.delete([uri, importer])}
              nil
            else
              mtime
            end
          end
      end

      def dependencies(uri, importer)
        stored_mtime, dependencies =
          with_dependency_cache {|cache| Sass::Util.destructure(cache[[uri, importer]])}

        if !stored_mtime || stored_mtime < mtime(uri, importer)
          dependencies = compute_dependencies(uri, importer)
          with_dependency_cache do |cache|
            cache[[uri, importer]] = [mtime(uri, importer), dependencies]
          end
        end

        dependencies
      end

      def dependency_updated?(css_mtime)
        proc do |uri, importer|
          next true if @actively_checking.include?(uri)
          begin
            @actively_checking << uri
            sass_mtime = mtime(uri, importer)
            !sass_mtime ||
              sass_mtime > css_mtime ||
              dependencies_stale?(uri, importer, css_mtime)
          ensure
            @actively_checking.delete uri
          end
        end
      end

      def compute_dependencies(uri, importer)
        tree(uri, importer).grep(Tree::ImportNode) do |n|
          next if n.css_import?
          file = n.imported_file
          key = [file.options[:filename], file.options[:importer]]
          @parse_trees[key] = file.to_tree
          key
        end.compact
      end

      def tree(uri, importer)
        @parse_trees[[uri, importer]] ||= importer.find(uri, @options).to_tree
      end

      def with_dependency_cache
        StalenessChecker.dependency_cache_mutex.synchronize do
          yield StalenessChecker.dependencies_cache
        end
      end
    end
  end
end
