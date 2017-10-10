require 'pathname'

module Sass::Tree
  class RuleNode < Node
    PARENT = '&'

    attr_accessor :rule

    attr_accessor :parsed_rules

    attr_accessor :resolved_rules

    attr_accessor :tabs

    attr_accessor :selector_source_range

    attr_accessor :group_end

    attr_accessor :stack_trace

    def initialize(rule, selector_source_range = nil)
      if rule.is_a?(Sass::Selector::CommaSequence)
        @rule = [rule.to_s]
        @parsed_rules = rule
      else
        merged = Sass::Util.merge_adjacent_strings(rule)
        @rule = Sass::Util.strip_string_array(merged)
        try_to_parse_non_interpolated_rules
      end
      @selector_source_range = selector_source_range
      @tabs = 0
      super()
    end

    def line=(line)
      @parsed_rules.line = line if @parsed_rules
      super
    end

    def filename=(filename)
      @parsed_rules.filename = filename if @parsed_rules
      super
    end

    def ==(other)
      self.class == other.class && rule == other.rule && super
    end

    def add_rules(node)
      @rule = Sass::Util.strip_string_array(
        Sass::Util.merge_adjacent_strings(@rule + ["\n"] + node.rule))
      try_to_parse_non_interpolated_rules
    end

    def continued?
      last = @rule.last
      last.is_a?(String) && last[-1] == ?,
    end

    def debug_info
      {:filename => filename && ("file://" + Sass::Util.escape_uri(File.expand_path(filename))),
       :line => line}
    end

    def invisible?
      resolved_rules.members.all? {|seq| seq.has_placeholder?}
    end

    private

    def try_to_parse_non_interpolated_rules
      @parsed_rules = nil
      return unless @rule.all? {|t| t.kind_of?(String)}

      parser = Sass::SCSS::StaticParser.new(@rule.join.strip, nil, nil, 1)
      @parsed_rules = parser.parse_selector rescue nil
    end
  end
end
