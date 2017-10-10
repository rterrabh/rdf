module Vagrant
  class Registry
    def initialize
      @items = {}
      @results_cache = {}
    end

    def register(key, &block)
      raise ArgumentError, "block required" if !block_given?
      @items[key] = block
    end

    def get(key)
      return nil if !@items.key?(key)
      return @results_cache[key] if @results_cache.key?(key)
      @results_cache[key] = @items[key].call
    end
    alias :[] :get

    def key?(key)
      @items.key?(key)
    end
    alias_method :has_key?, :key?

    def keys
      @items.keys
    end

    def each(&block)
      @items.each do |key, _|
        yield key, get(key)
      end
    end

    def length
      @items.keys.length
    end
    alias_method :size, :length

    def empty?
      @items.keys.empty?
    end

    def merge(other)
      self.class.new.tap do |result|
        result.merge!(self)
        result.merge!(other)
      end
    end

    def merge!(other)
      @items.merge!(other.__internal_state[:items])
      self
    end

    def to_hash
      result = {}
      self.each do |key, value|
        result[key] = value
      end

      result
    end

    def __internal_state
      {
        items: @items,
        results_cache: @results_cache
      }
    end
  end
end
