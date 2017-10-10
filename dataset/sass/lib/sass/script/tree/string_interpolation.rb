module Sass::Script::Tree
  class StringInterpolation < Node
    def initialize(before, mid, after)
      @before = before
      @mid = mid
      @after = after
    end

    def inspect
      "(string_interpolation #{@before.inspect} #{@mid.inspect} #{@after.inspect})"
    end

    def to_sass(opts = {})
      before_unquote, before_quote_char, before_str = parse_str(@before.to_sass(opts))
      after_unquote, after_quote_char, after_str = parse_str(@after.to_sass(opts))
      unquote = before_unquote || after_unquote ||
        (before_quote_char && !after_quote_char && !after_str.empty?) ||
        (!before_quote_char && after_quote_char && !before_str.empty?)
      quote_char =
        if before_quote_char && after_quote_char && before_quote_char != after_quote_char
          before_str.gsub!("\\'", "'")
          before_str.gsub!('"', "\\\"")
          after_str.gsub!("\\'", "'")
          after_str.gsub!('"', "\\\"")
          '"'
        else
          before_quote_char || after_quote_char
        end

      res = ""
      res << 'unquote(' if unquote
      res << quote_char if quote_char
      res << before_str
      res << '#{' << @mid.to_sass(opts) << '}'
      res << after_str
      res << quote_char if quote_char
      res << ')' if unquote
      res
    end

    def children
      [@before, @mid, @after].compact
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3013> <not yet classified>
      node.instance_variable_set('@before', @before.deep_copy) if @before
      #nodyna <instance_variable_set-3014> <not yet classified>
      node.instance_variable_set('@mid', @mid.deep_copy)
      #nodyna <instance_variable_set-3015> <not yet classified>
      node.instance_variable_set('@after', @after.deep_copy) if @after
      node
    end

    protected

    def _perform(environment)
      res = ""
      before = @before.perform(environment)
      res << before.value
      mid = @mid.perform(environment)
      res << (mid.is_a?(Sass::Script::Value::String) ? mid.value : mid.to_s(:quote => :none))
      res << @after.perform(environment).value
      opts(Sass::Script::Value::String.new(res, before.type))
    end

    private

    def parse_str(str)
      case str
      when /^unquote\((["'])(.*)\1\)$/
        return true, $1, $2
      when '""'
        return false, nil, ""
      when /^(["'])(.*)\1$/
        return false, $1, $2
      else
        return false, nil, str
      end
    end
  end
end
