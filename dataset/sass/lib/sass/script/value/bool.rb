module Sass::Script::Value
  class Bool < Base
    TRUE  = new(true)

    FALSE = new(false)

    def self.new(value)
      value ? TRUE : FALSE
    end

    attr_reader :value
    alias_method :to_bool, :value

    def to_s(opts = {})
      @value.to_s
    end
    alias_method :to_sass, :to_s
  end
end
