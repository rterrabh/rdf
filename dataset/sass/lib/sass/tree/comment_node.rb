require 'sass/tree/node'

module Sass::Tree
  class CommentNode < Node
    attr_accessor :value

    attr_accessor :resolved_value

    attr_accessor :type

    def initialize(value, type)
      @value = Sass::Util.with_extracted_values(value) {|str| normalize_indentation str}
      @type = type
      super()
    end

    def ==(other)
      self.class == other.class && value == other.value && type == other.type
    end

    def invisible?
      case @type
      when :loud; false
      when :silent; true
      else; style == :compressed
      end
    end

    def lines
      @value.inject(0) do |s, e|
        next s + e.count("\n") if e.is_a?(String)
        next s
      end
    end

    private

    def normalize_indentation(str)
      ind = str.split("\n").inject(str[/^[ \t]*/].split("")) do |pre, line|
        line[/^[ \t]*/].split("").zip(pre).inject([]) do |arr, (a, b)|
          break arr if a != b
          arr << a
        end
      end.join
      str.gsub(/^#{ind}/, '')
    end
  end
end
