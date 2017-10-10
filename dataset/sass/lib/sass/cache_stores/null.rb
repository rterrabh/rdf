module Sass
  module CacheStores
    class Null < Base
      def initialize
        @keys = {}
      end

      def _retrieve(key, version, sha)
        nil
      end

      def _store(key, version, sha, contents)
        @keys[key] = true
      end

      def was_set?(key)
        @keys[key]
      end
    end
  end
end
