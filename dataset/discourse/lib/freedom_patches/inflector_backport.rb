
module ActiveSupport
  module Inflector

    LRU_CACHE_SIZE = 200
    LRU_CACHES = []

    def self.clear_memoize!
      LRU_CACHES.each(&:clear)
    end

    def self.memoize(*args)
      args.each do |method_name|
        cache = LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
        LRU_CACHES << cache

        uncached = "#{method_name}_without_cache"
        alias_method uncached, method_name

        #nodyna <define_method-346> <DM MODERATE (array)>
        define_method(method_name) do |*args|
          found = true
          data = cache.fetch(args){found = false}
          unless found
            #nodyna <send-347> <SD MODERATE (array)>
            cache[args] = data = send(uncached, *args)
          end
          data.dup
        end
      end
    end

    memoize :pluralize, :singularize, :camelize, :underscore, :humanize,
            :titleize, :tableize, :classify, :foreign_key
  end
end

module ActiveSupport
  module Inflector
    class Inflections
      def self.clear_memoize(*args)
        args.each do |method_name|
          orig = "#{method_name}_without_clear_memoize"
          alias_method orig, method_name
          #nodyna <define_method-348> <DM MODERATE (array)>
          define_method(method_name) do |*args|
            ActiveSupport::Inflector.clear_memoize!
            #nodyna <send-349> <SD MODERATE (change-prone variables)>
            send(orig, *args)
          end
        end
      end

      clear_memoize :acronym, :plural, :singular, :irregular, :uncountable, :human, :clear
    end
  end
end





