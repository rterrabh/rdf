module Vagrant
  module Util
    class HashWithIndifferentAccess < ::Hash
      def initialize(hash={}, &block)
        super(&block)

        hash.each do |key, value|
          self[convert_key(key)] = value
        end
      end

      def [](key)
        super(convert_key(key))
      end

      def []=(key, value)
        super(convert_key(key), value)
      end

      def delete(key)
        super(convert_key(key))
      end

      def values_at(*indices)
        indices.collect { |key| self[convert_key(key)] }
      end

      def merge(other)
        dup.merge!(other)
      end

      def merge!(other)
        other.each do |key, value|
          self[convert_key(key)] = value
        end
        self
      end

      def key?(key)
        super(convert_key(key))
      end

      alias_method :include?, :key?
      alias_method :has_key?, :key?
      alias_method :member?, :key?

      protected

      def convert_key(key)
        key.is_a?(Symbol) ? key.to_s : key
      end
    end
  end
end
