module Sass::Script::Value
  class String < Base
    attr_reader :value

    attr_reader :type

    def self.value(contents)
      contents.gsub("\\\n", "").gsub(/\\(?:([0-9a-fA-F]{1,6})\s?|(.))/) do
        next $2 if $2
        code_point = $1.to_i(16)
        if code_point == 0 || code_point > 0x10FFFF ||
            (code_point >= 0xD800 && code_point <= 0xDFFF)
          '�'
        else
          [code_point].pack("U")
        end
      end
    end

    def self.quote(contents, quote = nil)
      unless contents =~ /[\n\\"']/
        quote ||= '"'
        return "#{quote}#{contents}#{quote}"
      end

      if quote.nil?
        if contents.include?('"')
          if contents.include?("'")
            quote = '"'
          else
            quote = "'"
          end
        else
          quote = '"'
        end
      end

      contents = contents.gsub("\\", "\\\\\\\\")

      if quote == '"'
        contents = contents.gsub('"', "\\\"")
      else
        contents = contents.gsub("'", "\\'")
      end

      contents = contents.gsub(/\n(?![a-fA-F0-9\s])/, "\\a").gsub("\n", "\\a ")
      "#{quote}#{contents}#{quote}"
    end

    def initialize(value, type = :identifier)
      super(value)
      @type = type
    end

    def plus(other)
      other_value = if other.is_a?(Sass::Script::Value::String)
                      other.value
                    else
                      other.to_s(:quote => :none)
                    end
      Sass::Script::Value::String.new(value + other_value, type)
    end

    def to_s(opts = {})
      return @value.gsub(/\n\s*/, ' ') if opts[:quote] == :none || @type == :identifier
      Sass::Script::Value::String.quote(value, opts[:quote])
    end

    def to_sass(opts = {})
      to_s
    end

    def inspect
      String.quote(value)
    end
  end
end
