module Sass::Script::Value
  class Null < Base
    NULL = new(nil)

    def self.new
      NULL
    end

    def to_bool
      false
    end

    def null?
      true
    end

    def to_s(opts = {})
      ''
    end

    def to_sass(opts = {})
      'null'
    end

    def inspect
      'null'
    end
  end
end
