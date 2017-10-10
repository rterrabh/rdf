module Sass
  module Importers
    class Base
      def find_relative(uri, base, options)
        Sass::Util.abstract(self)
      end

      def find(uri, options)
        Sass::Util.abstract(self)
      end

      def mtime(uri, options)
        Sass::Util.abstract(self)
      end

      def key(uri, options)
        Sass::Util.abstract(self)
      end

      def public_url(uri, sourcemap_directory)
        return if @public_url_warning_issued
        @public_url_warning_issued = true
        Sass::Util.sass_warn <<WARNING
WARNING: #{self.class.name} should define the #public_url method.
WARNING
        nil
      end

      def to_s
        Sass::Util.abstract(self)
      end

      def directories_to_watch
        []
      end

      def watched_file?(filename)
        false
      end
    end
  end
end
