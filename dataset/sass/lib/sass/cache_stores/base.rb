module Sass
  module CacheStores
    class Base
      def _store(key, version, sha, contents)
        raise "#{self.class} must implement #_store."
      end

      def _retrieve(key, version, sha)
        raise "#{self.class} must implement #_retrieve."
      end

      def store(key, sha, root)
        _store(key, Sass::VERSION, sha, Marshal.dump(root))
      rescue TypeError, LoadError => e
        Sass::Util.sass_warn "Warning. Error encountered while saving cache #{path_to(key)}: #{e}"
        nil
      end

      def retrieve(key, sha)
        contents = _retrieve(key, Sass::VERSION, sha)
        Marshal.load(contents) if contents
      rescue EOFError, TypeError, ArgumentError, LoadError => e
        Sass::Util.sass_warn "Warning. Error encountered while reading cache #{path_to(key)}: #{e}"
        nil
      end

      def key(sass_dirname, sass_basename)
        dir = Digest::SHA1.hexdigest(sass_dirname)
        filename = "#{sass_basename}c"
        "#{dir}/#{filename}"
      end
    end
  end
end
