module Rake

  class TaskArguments
    include Enumerable

    attr_reader :names

    def initialize(names, values, parent=nil)
      @names = names
      @parent = parent
      @hash = {}
      @values = values
      names.each_with_index { |name, i|
        @hash[name.to_sym] = values[i] unless values[i].nil?
      }
    end

    def to_a
      @values.dup
    end

    def extras
      @values[@names.length..-1] || []
    end

    def new_scope(names)
      values = names.map { |n| self[n] }
      self.class.new(names, values + extras, self)
    end

    def [](index)
      lookup(index.to_sym)
    end

    def with_defaults(defaults)
      @hash = defaults.merge(@hash)
    end

    def each(&block)
      @hash.each(&block)
    end

    def values_at(*keys)
      keys.map { |k| lookup(k) }
    end

    def method_missing(sym, *args)
      lookup(sym.to_sym)
    end

    def to_hash
      @hash
    end

    def to_s # :nodoc:
      @hash.inspect
    end

    def inspect # :nodoc:
      to_s
    end

    def has_key?(key)
      @hash.has_key?(key)
    end

    protected

    def lookup(name) # :nodoc:
      if @hash.has_key?(name)
        @hash[name]
      elsif @parent
        @parent.lookup(name)
      end
    end
  end

  EMPTY_TASK_ARGS = TaskArguments.new([], []) # :nodoc:
end
