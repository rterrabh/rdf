module Sass::Script::Tree
  class Node
    attr_reader :options

    attr_accessor :line

    attr_accessor :source_range

    attr_accessor :filename

    def options=(options)
      @options = options
      children.each do |c|
        if c.is_a? Hash
          c.values.each {|v| v.options = options}
        else
          c.options = options
        end
      end
    end

    def perform(environment)
      _perform(environment)
    rescue Sass::SyntaxError => e
      e.modify_backtrace(:line => line)
      raise e
    end

    def children
      Sass::Util.abstract(self)
    end

    def to_sass(opts = {})
      Sass::Util.abstract(self)
    end

    def deep_copy
      Sass::Util.abstract(self)
    end

    def force_division!
      children.each {|c| c.force_division!}
    end

    protected

    def dasherize(s, opts)
      if opts[:dasherize]
        s.gsub(/_/, '-')
      else
        s
      end
    end

    def _perform(environment)
      Sass::Util.abstract(self)
    end

    def opts(value)
      value.options = options
      value
    end
  end
end
