module Sass::Script::Value
  class Map < Base
    attr_reader :value
    alias_method :to_h, :value

    def initialize(hash)
      super(Sass::Util.ordered_hash(hash))
    end

    def options=(options)
      super
      value.each do |k, v|
        k.options = options
        v.options = options
      end
    end

    def separator
      :comma unless value.empty?
    end

    def to_a
      value.map do |k, v|
        list = List.new([k, v], :space)
        list.options = options
        list
      end
    end

    def eq(other)
      Bool.new(other.is_a?(Map) && value == other.value)
    end

    def hash
      @hash ||= value.hash
    end

    def to_s(opts = {})
      raise Sass::SyntaxError.new("#{inspect} isn't a valid CSS value.")
    end

    def to_sass(opts = {})
      return "()" if value.empty?

      to_sass = lambda do |value|
        if value.is_a?(List) && value.separator == :comma
          "(#{value.to_sass(opts)})"
        else
          value.to_sass(opts)
        end
      end

      "(#{value.map {|(k, v)| "#{to_sass[k]}: #{to_sass[v]}"}.join(', ')})"
    end
    alias_method :inspect, :to_sass
  end
end
