module Sass::Script::Tree
  class Interpolation < Node
    attr_reader :before

    attr_reader :mid

    attr_reader :after

    attr_reader :whitespace_before

    attr_reader :whitespace_after

    attr_reader :originally_text

    attr_reader :warn_for_color

    def initialize(before, mid, after, wb, wa, originally_text = false, warn_for_color = false)
      @before = before
      @mid = mid
      @after = after
      @whitespace_before = wb
      @whitespace_after = wa
      @originally_text = originally_text
      @warn_for_color = warn_for_color
    end

    def inspect
      "(interpolation #{@before.inspect} #{@mid.inspect} #{@after.inspect})"
    end

    def to_sass(opts = {})
      res = ""
      res << @before.to_sass(opts) if @before
      res << ' ' if @before && @whitespace_before
      res << '#{' unless @originally_text
      res << @mid.to_sass(opts)
      res << '}' unless @originally_text
      res << ' ' if @after && @whitespace_after
      res << @after.to_sass(opts) if @after
      res
    end

    def children
      [@before, @mid, @after].compact
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3010> <not yet classified>
      node.instance_variable_set('@before', @before.deep_copy) if @before
      #nodyna <instance_variable_set-3011> <not yet classified>
      node.instance_variable_set('@mid', @mid.deep_copy)
      #nodyna <instance_variable_set-3012> <not yet classified>
      node.instance_variable_set('@after', @after.deep_copy) if @after
      node
    end

    protected

    def _perform(environment)
      res = ""
      res << @before.perform(environment).to_s if @before
      res << " " if @before && @whitespace_before

      val = @mid.perform(environment)
      if @warn_for_color && val.is_a?(Sass::Script::Value::Color) && val.name
        alternative = Operation.new(Sass::Script::Value::String.new("", :string), @mid, :plus)
        Sass::Util.sass_warn <<MESSAGE
WARNING on line #{line}, column #{source_range.start_pos.offset}#{" of #{filename}" if filename}:
You probably don't mean to use the color value `#{val}' in interpolation here.
It may end up represented as #{val.inspect}, which will likely produce invalid CSS.
Always quote color names when using them as strings (for example, "#{val}").
If you really want to use the color value here, use `#{alternative.to_sass}'.
MESSAGE
      end

      res << val.to_s(:quote => :none)
      res << " " if @after && @whitespace_after
      res << @after.perform(environment).to_s if @after
      opts(Sass::Script::Value::String.new(res))
    end
  end
end
