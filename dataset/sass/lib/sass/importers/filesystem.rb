require 'set'

module Sass
  module Importers
    class Filesystem < Base
      attr_accessor :root

      def initialize(root)
        @root = File.expand_path(root)
        @real_root = Sass::Util.realpath(@root).to_s
        @same_name_warnings = Set.new
      end

      def find_relative(name, base, options)
        _find(File.dirname(base), name, options)
      end

      def find(name, options)
        _find(@root, name, options)
      end

      def mtime(name, options)
        file, _ = Sass::Util.destructure(find_real_file(@root, name, options))
        File.mtime(file) if file
      rescue Errno::ENOENT
        nil
      end

      def key(name, options)
        [self.class.name + ":" + File.dirname(File.expand_path(name)),
         File.basename(name)]
      end

      def to_s
        @root
      end

      def hash
        @root.hash
      end

      def eql?(other)
        !other.nil? && other.respond_to?(:root) && root.eql?(other.root)
      end

      def directories_to_watch
        [root]
      end

      def watched_file?(filename)
        filename =~ /\.s[ac]ss$/ && filename.start_with?(@real_root + File::SEPARATOR)
      end

      def public_url(name, sourcemap_directory)
        file_pathname = Sass::Util.cleanpath(Sass::Util.absolute_path(name, @root))
        return Sass::Util.file_uri_from_path(file_pathname) if sourcemap_directory.nil?

        sourcemap_pathname = Sass::Util.cleanpath(sourcemap_directory)
        begin
          Sass::Util.file_uri_from_path(
            Sass::Util.relative_path_from(file_pathname, sourcemap_pathname))
        rescue ArgumentError # when a relative path cannot be constructed
          Sass::Util.file_uri_from_path(file_pathname)
        end
      end

      protected

      def remove_root(name)
        if name.index(@root + "/") == 0
          name[(@root.length + 1)..-1]
        else
          name
        end
      end

      def extensions
        {'sass' => :sass, 'scss' => :scss}
      end

      def possible_files(name)
        name = escape_glob_characters(name)
        dirname, basename, extname = split(name)
        sorted_exts = extensions.sort
        syntax = extensions[extname]

        if syntax
          ret = [["#{dirname}/{_,}#{basename}.#{extensions.invert[syntax]}", syntax]]
        else
          ret = sorted_exts.map {|ext, syn| ["#{dirname}/{_,}#{basename}.#{ext}", syn]}
        end

        ret.map {|f, s| [f.sub(/^\.\//, ''), s]}
      end

      def escape_glob_characters(name)
        name.gsub(/[\*\[\]\{\}\?]/) do |char|
          "\\#{char}"
        end
      end

      REDUNDANT_DIRECTORY = /#{Regexp.escape(File::SEPARATOR)}\.#{Regexp.escape(File::SEPARATOR)}/
      def find_real_file(dir, name, options)
        dir = dir.gsub(File::ALT_SEPARATOR, File::SEPARATOR) unless File::ALT_SEPARATOR.nil?
        name = name.gsub(File::ALT_SEPARATOR, File::SEPARATOR) unless File::ALT_SEPARATOR.nil?

        found = possible_files(remove_root(name)).map do |f, s|
          path = (dir == "." || Sass::Util.pathname(f).absolute?) ? f :
            "#{escape_glob_characters(dir)}/#{f}"
          Dir[path].map do |full_path|
            full_path.gsub!(REDUNDANT_DIRECTORY, File::SEPARATOR)
            [Sass::Util.cleanpath(full_path).to_s, s]
          end
        end
        found = Sass::Util.flatten(found, 1)
        return if found.empty?

        if found.size > 1 && !@same_name_warnings.include?(found.first.first)
          found.each {|(f, _)| @same_name_warnings << f}
          relative_to = Sass::Util.pathname(dir)
          if options[:_from_import_node]
            candidates = found.map do |(f, _)|
              "  " + Sass::Util.pathname(f).relative_path_from(relative_to).to_s
            end.join("\n")
            raise Sass::SyntaxError.new(<<MESSAGE)
It's not clear which file to import for '@import "#{name}"'.
Candidates:
Please delete or rename all but one of these files.
MESSAGE
          else
            candidates = found.map {|(f, _)| "    " + File.basename(f)}.join("\n")
            Sass::Util.sass_warn <<WARNING
WARNING: In #{File.dirname(name)}:
  There are multiple files that match the name "#{File.basename(name)}":
WARNING
          end
        end
        found.first
      end

      def split(name)
        extension = nil
        dirname, basename = File.dirname(name), File.basename(name)
        if basename =~ /^(.*)\.(#{extensions.keys.map {|e| Regexp.escape(e)}.join('|')})$/
          basename = $1
          extension = $2
        end
        [dirname, basename, extension]
      end

      private

      def _find(dir, name, options)
        full_filename, syntax = Sass::Util.destructure(find_real_file(dir, name, options))
        return unless full_filename && File.readable?(full_filename)

        full_filename = full_filename.tr("\\", "/") if Sass::Util.windows?

        options[:syntax] = syntax
        options[:filename] = full_filename
        options[:importer] = self
        Sass::Engine.new(File.read(full_filename), options)
      end
    end
  end
end
