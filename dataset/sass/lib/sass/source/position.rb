module Sass::Source
  class Position
    attr_accessor :line

    attr_accessor :offset

    def initialize(line, offset)
      @line = line
      @offset = offset
    end

    def inspect
      "#{line.inspect}:#{offset.inspect}"
    end

    def after(str)
      newlines = str.count("\n")
      Position.new(line + newlines,
        if newlines == 0
          offset + str.length
        else
          str.length - str.rindex("\n") - 1
        end)
    end
  end
end
