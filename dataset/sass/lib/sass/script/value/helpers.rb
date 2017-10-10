module Sass::Script::Value
  module Helpers
    def bool(value)
      Bool.new(value)
    end

    def hex_color(value, alpha = nil)
      Color.from_hex(value, alpha)
    end

    def hsl_color(hue, saturation, lightness, alpha = nil)
      attrs = {:hue => hue, :saturation => saturation, :lightness => lightness}
      attrs[:alpha] = alpha if alpha
      Color.new(attrs)
    end

    def rgb_color(red, green, blue, alpha = nil)
      attrs = {:red => red, :green => green, :blue => blue}
      attrs[:alpha] = alpha if alpha
      Color.new(attrs)
    end

    def number(number, unit_string = nil)
      Number.new(number, *parse_unit_string(unit_string))
    end

    def list(*elements)
      unless elements.last.is_a?(Symbol)
        raise ArgumentError.new("A list type of :space or :comma must be specified.")
      end
      separator = elements.pop
      if elements.size == 1 && elements.first.is_a?(Array)
        elements = elements.first
      end
      Sass::Script::Value::List.new(elements, separator)
    end

    def map(hash)
      Map.new(hash)
    end

    def null
      Sass::Script::Value::Null.new
    end

    def quoted_string(str)
      Sass::Script::String.new(str, :string)
    end

    def unquoted_string(str)
      Sass::Script::String.new(str, :identifier)
    end
    alias_method :identifier, :unquoted_string

    def parse_selector(value, name = nil, allow_parent_ref = false)
      str = normalize_selector(value, name)
      begin
        Sass::SCSS::StaticParser.new(str, nil, nil, 1, 1, allow_parent_ref).parse_selector
      rescue Sass::SyntaxError => e
        err = "#{value.inspect} is not a valid selector: #{e}"
        err = "$#{name.to_s.gsub('_', '-')}: #{err}" if name
        raise ArgumentError.new(err)
      end
    end

    def parse_complex_selector(value, name = nil, allow_parent_ref = false)
      selector = parse_selector(value, name, allow_parent_ref)
      return seq if selector.members.length == 1

      err = "#{value.inspect} is not a complex selector"
      err = "$#{name.to_s.gsub('_', '-')}: #{err}" if name
      raise ArgumentError.new(err)
    end

    def parse_compound_selector(value, name = nil, allow_parent_ref = false)
      assert_type value, :String, name
      selector = parse_selector(value, name, allow_parent_ref)
      seq = selector.members.first
      sseq = seq.members.first
      if selector.members.length == 1 && seq.members.length == 1 &&
          sseq.is_a?(Sass::Selector::SimpleSequence)
        return sseq
      end

      err = "#{value.inspect} is not a compound selector"
      err = "$#{name.to_s.gsub('_', '-')}: #{err}" if name
      raise ArgumentError.new(err)
    end

    def calc?(literal)
      if literal.is_a?(Sass::Script::Value::String)
        literal.value =~ /calc\(/
      end
    end

    private

    def normalize_selector(value, name)
      if (str = selector_to_str(value))
        return str
      end

      err = "#{value.inspect} is not a valid selector: it must be a string,\n" +
        "a list of strings, or a list of lists of strings"
      err = "$#{name.to_s.gsub('_', '-')}: #{err}" if name
      raise ArgumentError.new(err)
    end

    def selector_to_str(value)
      return value.value if value.is_a?(Sass::Script::String)
      return unless value.is_a?(Sass::Script::List)

      if value.separator == :comma
        return value.to_a.map do |complex|
          next complex.value if complex.is_a?(Sass::Script::String)
          return unless complex.is_a?(Sass::Script::List) && complex.separator == :space
          return unless (str = selector_to_str(complex))
          str
        end.join(', ')
      end

      value.to_a.map do |compound|
        return unless compound.is_a?(Sass::Script::String)
        compound.value
      end.join(' ')
    end

    VALID_UNIT = /#{Sass::SCSS::RX::NMSTART}#{Sass::SCSS::RX::NMCHAR}|%*/

    def parse_unit_string(unit_string)
      denominator_units = numerator_units = Sass::Script::Value::Number::NO_UNITS
      return numerator_units, denominator_units unless unit_string && unit_string.length > 0
      num_over_denominator = unit_string.split(/ *\/ */)
      unless (1..2).include?(num_over_denominator.size)
        raise ArgumentError.new("Malformed unit string: #{unit_string}")
      end
      numerator_units = num_over_denominator[0].split(/ *\* */)
      denominator_units = (num_over_denominator[1] || "").split(/ *\* */)
      [[numerator_units, "numerator"], [denominator_units, "denominator"]].each do |units, name|
        if unit_string =~ /\// && units.size == 0
          raise ArgumentError.new("Malformed unit string: #{unit_string}")
        end
        if units.any? {|unit| unit !~ VALID_UNIT}
          raise ArgumentError.new("Malformed #{name} in unit string: #{unit_string}")
        end
      end
      [numerator_units, denominator_units]
    end
  end
end
