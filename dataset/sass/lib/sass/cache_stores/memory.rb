module Sass
  module CacheStores
    class Memory < Base
      def _dump(depth)
        ""
      end

      def self._load(repr)
        Memory.new
      end

      def initialize
        @contents = {}
      end

      def retrieve(key, sha)
        if @contents.has_key?(key)
          return unless @contents[key][:sha] == sha
          obj = @contents[key][:obj]
          obj.respond_to?(:deep_copy) ? obj.deep_copy : obj.dup
        end
      end

      def store(key, sha, obj)
        @contents[key] = {:sha => sha, :obj => obj}
      end

      def reset!
        @contents = {}
      end
    end
  end
end
