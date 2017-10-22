require 'delegate'
require 'sass/util'

module Sass
  module Util
    require 'sass/util/ordered_hash' if ruby1_8?
    class NormalizedMap
      def initialize(map = nil)
        @key_strings = {}
        @map = Util.ruby1_8? ? OrderedHash.new : {}

        map.each {|key, value| self[key] = value} if map
      end

      def normalize(key)
        key.tr("-", "_")
      end

      def denormalize(key)
        @key_strings[normalize(key)] || key
      end

      def []=(k, v)
        normalized = normalize(k)
        @map[normalized] = v
        @key_strings[normalized] = k
        v
      end

      def [](k)
        @map[normalize(k)]
      end

      def has_key?(k)
        @map.has_key?(normalize(k))
      end

      def delete(k)
        normalized = normalize(k)
        @key_strings.delete(normalized)
        @map.delete(normalized)
      end

      def as_stored
        Sass::Util.map_keys(@map) {|k| @key_strings[k]}
      end

      def empty?
        @map.empty?
      end

      def values
        @map.values
      end

      def keys
        @map.keys
      end

      def each
        @map.each {|k, v| yield(k, v)}
      end

      def size
        @map.size
      end

      def to_hash
        @map.dup
      end

      def to_a
        @map.to_a
      end

      def map
        @map.map {|k, v| yield(k, v)}
      end

      def dup
        d = super
        #nodyna <instance_variable_set-3039> <IVS MODERATE (private access)>
        #nodyna <send-3040> <SD TRIVIAL (public methods)>
        d.send(:instance_variable_set, "@map", @map.dup)
        d
      end

      def sort_by
        @map.sort_by {|k, v| yield k, v}
      end

      def update(map)
        map = map.as_stored if map.is_a?(NormalizedMap)
        map.each {|k, v| self[k] = v}
      end

      def method_missing(method, *args, &block)
        if Sass.tests_running
          raise ArgumentError.new("The method #{method} must be implemented explicitly")
        end
        #nodyna <send-3041> <SD COMPLEX (change-prone variables)>
        @map.send(method, *args, &block)
      end

      if Sass::Util.ruby1_8?
        def respond_to?(method, include_private = false)
          super || @map.respond_to?(method, include_private)
        end
      end

      def respond_to_missing?(method, include_private = false)
        @map.respond_to?(method, include_private)
      end
    end
  end
end
