module Sass
  module CacheStores
    class Chain < Base
      def initialize(*caches)
        @caches = caches
      end

      def store(key, sha, obj)
        @caches.each {|c| c.store(key, sha, obj)}
      end

      def retrieve(key, sha)
        @caches.each_with_index do |c, i|
          obj = c.retrieve(key, sha)
          next unless obj
          @caches[0...i].each {|prev| prev.store(key, sha, obj)}
          return obj
        end
        nil
      end
    end
  end
end
