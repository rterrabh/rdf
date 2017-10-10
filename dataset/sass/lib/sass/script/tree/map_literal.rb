module Sass::Script::Tree
  class MapLiteral < Node
    attr_reader :pairs

    def initialize(pairs)
      @pairs = pairs
    end

    def children
      @pairs.flatten
    end

    def to_sass(opts = {})
      return "()" if pairs.empty?

      to_sass = lambda do |value|
        if value.is_a?(ListLiteral) && value.separator == :comma
          "(#{value.to_sass(opts)})"
        else
          value.to_sass(opts)
        end
      end

      "(" + pairs.map {|(k, v)| "#{to_sass[k]}: #{to_sass[v]}"}.join(', ') + ")"
    end
    alias_method :inspect, :to_sass

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3025> <not yet classified>
      node.instance_variable_set('@pairs',
        pairs.map {|(k, v)| [k.deep_copy, v.deep_copy]})
      node
    end

    protected

    def _perform(environment)
      keys = Set.new
      map = Sass::Script::Value::Map.new(Sass::Util.to_hash(pairs.map do |(k, v)|
        k, v = k.perform(environment), v.perform(environment)
        if keys.include?(k)
          raise Sass::SyntaxError.new("Duplicate key #{k.inspect} in map #{to_sass}.")
        end
        keys << k
        [k, v]
      end))
      map.options = options
      map
    end
  end
end
