require 'sass/script/value/helpers'

module Sass::Script
  module Functions
    @signatures = {}

    Signature = Struct.new(:args, :delayed_args, :var_args, :var_kwargs, :deprecated)

    def self.declare(method_name, args, options = {})
      delayed_args = []
      args = args.map do |a|
        a = a.to_s
        if a[0] == ?&
          a = a[1..-1]
          delayed_args << a
        end
        a
      end
      if delayed_args.any? && method_name != :if
        raise ArgumentError.new("Delayed arguments are not allowed for method #{method_name}")
      end
      @signatures[method_name] ||= []
      @signatures[method_name] << Signature.new(
        args,
        delayed_args,
        options[:var_args],
        options[:var_kwargs],
        options[:deprecated] && options[:deprecated].map {|a| a.to_s})
    end

    def self.signature(method_name, arg_arity, kwarg_arity)
      return unless @signatures[method_name]
      @signatures[method_name].each do |signature|
        sig_arity = signature.args.size
        return signature if sig_arity == arg_arity + kwarg_arity
        next unless sig_arity < arg_arity + kwarg_arity

        t_arg_arity, t_kwarg_arity = arg_arity, kwarg_arity
        if sig_arity > t_arg_arity
          t_kwarg_arity -= (sig_arity - t_arg_arity)
          t_arg_arity = sig_arity
        end

        if   (t_arg_arity == sig_arity ||   t_arg_arity > sig_arity && signature.var_args) &&
           (t_kwarg_arity == 0         || t_kwarg_arity > 0         && signature.var_kwargs)
          return signature
        end
      end
      @signatures[method_name].first
    end

    def self.random_seed=(seed)
      @random_number_generator = Sass::Util::CrossPlatformRandom.new(seed)
    end

    def self.random_number_generator
      @random_number_generator ||= Sass::Util::CrossPlatformRandom.new
    end

    class EvaluationContext
      include Functions
      include Value::Helpers

      TYPE_NAMES = {:ArgList => 'variable argument list'}

      attr_reader :environment

      attr_reader :options

      def initialize(environment)
        @environment = environment
        @options = environment.options
      end

      def assert_type(value, type, name = nil)
        #nodyna <const_get-3030> <CG MODERATE (change-prone variables)>
        klass = Sass::Script::Value.const_get(type)
        return if value.is_a?(klass)
        return if value.is_a?(Sass::Script::Value::List) && type == :Map && value.value.empty?
        err = "#{value.inspect} is not a #{TYPE_NAMES[type] || type.to_s.downcase}"
        err = "$#{name.to_s.gsub('_', '-')}: " + err if name
        raise ArgumentError.new(err)
      end

      def assert_unit(number, unit, name = nil)
        assert_type number, :Number, name
        return if number.is_unit?(unit)
        expectation = unit ? "have a unit of #{unit}" : "be unitless"
        if name
          raise ArgumentError.new("Expected $#{name} to #{expectation} but got #{number}")
        else
          raise ArgumentError.new("Expected #{number} to #{expectation}")
        end
      end

      def assert_integer(number, name = nil)
        assert_type number, :Number, name
        return if number.int?
        if name
          raise ArgumentError.new("Expected $#{name} to be an integer but got #{number}")
        else
          raise ArgumentError.new("Expected #{number} to be an integer")
        end
      end

      def perform(node, env = environment.caller)
        if node.is_a?(Sass::Script::Value::Base)
          node
        else
          node.perform(env)
        end
      end
    end

    class << self
      alias_method :callable?, :public_method_defined?

      private

      def include(*args)
        r = super
        #nodyna <send-3031> <SD TRIVIAL (public functions)>
        EvaluationContext.send :include, self
        r
      end
    end

    def rgb(red, green, blue)
      if calc?(red) || calc?(green) || calc?(blue)
        return unquoted_string("rgb(#{red}, #{green}, #{blue})")
      end
      assert_type red, :Number, :red
      assert_type green, :Number, :green
      assert_type blue, :Number, :blue

      color_attrs = [[red, :red], [green, :green], [blue, :blue]].map do |(c, name)|
        if c.is_unit?("%")
          c.value * 255 / 100.0
        elsif c.unitless?
          c.value
        else
          raise ArgumentError.new("Expected #{c} to be unitless or have a unit of % but got #{c}")
        end
      end

      Sass::Script::Value::Color.new(color_attrs)
    end
    declare :rgb, [:red, :green, :blue]

    def rgba(*args)
      case args.size
      when 2
        color, alpha = args

        assert_type color, :Color, :color
        if calc?(alpha)
          unquoted_string("rgba(#{color.red}, #{color.green}, #{color.blue}, #{alpha})")
        else
          assert_type alpha, :Number, :alpha
          check_alpha_unit alpha, 'rgba'
          color.with(:alpha => alpha.value)
        end
      when 4
        red, green, blue, alpha = args
        if calc?(red) || calc?(green) || calc?(blue) || calc?(alpha)
          unquoted_string("rgba(#{red}, #{green}, #{blue}, #{alpha})")
        else
          rgba(rgb(red, green, blue), alpha)
        end
      else
        raise ArgumentError.new("wrong number of arguments (#{args.size} for 4)")
      end
    end
    declare :rgba, [:red, :green, :blue, :alpha]
    declare :rgba, [:color, :alpha]

    def hsl(hue, saturation, lightness)
      if calc?(hue) || calc?(saturation) || calc?(lightness)
        unquoted_string("hsl(#{hue}, #{saturation}, #{lightness})")
      else
        hsla(hue, saturation, lightness, number(1))
      end
    end
    declare :hsl, [:hue, :saturation, :lightness]

    def hsla(hue, saturation, lightness, alpha)
      if calc?(hue) || calc?(saturation) || calc?(lightness) || calc?(alpha)
        return unquoted_string("hsla(#{hue}, #{saturation}, #{lightness}, #{alpha})")
      end
      assert_type hue, :Number, :hue
      assert_type saturation, :Number, :saturation
      assert_type lightness, :Number, :lightness
      assert_type alpha, :Number, :alpha
      check_alpha_unit alpha, 'hsla'

      h = hue.value
      s = saturation.value
      l = lightness.value

      Sass::Script::Value::Color.new(
        :hue => h, :saturation => s, :lightness => l, :alpha => alpha.value)
    end
    declare :hsla, [:hue, :saturation, :lightness, :alpha]

    def red(color)
      assert_type color, :Color, :color
      number(color.red)
    end
    declare :red, [:color]

    def green(color)
      assert_type color, :Color, :color
      number(color.green)
    end
    declare :green, [:color]

    def blue(color)
      assert_type color, :Color, :color
      number(color.blue)
    end
    declare :blue, [:color]

    def hue(color)
      assert_type color, :Color, :color
      number(color.hue, "deg")
    end
    declare :hue, [:color]

    def saturation(color)
      assert_type color, :Color, :color
      number(color.saturation, "%")
    end
    declare :saturation, [:color]

    def lightness(color)
      assert_type color, :Color, :color
      number(color.lightness, "%")
    end
    declare :lightness, [:color]

    def alpha(*args)
      if args.all? do |a|
           a.is_a?(Sass::Script::Value::String) && a.type == :identifier &&
             a.value =~ /^[a-zA-Z]+\s*=/
         end
        return identifier("alpha(#{args.map {|a| a.to_s}.join(", ")})")
      end

      raise ArgumentError.new("wrong number of arguments (#{args.size} for 1)") if args.size != 1

      assert_type args.first, :Color, :color
      number(args.first.alpha)
    end
    declare :alpha, [:color]

    def opacity(color)
      if color.is_a?(Sass::Script::Value::Number)
        return identifier("opacity(#{color})")
      end
      assert_type color, :Color, :color
      number(color.alpha)
    end
    declare :opacity, [:color]

    def opacify(color, amount)
      _adjust(color, amount, :alpha, 0..1, :+)
    end
    declare :opacify, [:color, :amount]

    alias_method :fade_in, :opacify
    declare :fade_in, [:color, :amount]

    def transparentize(color, amount)
      _adjust(color, amount, :alpha, 0..1, :-)
    end
    declare :transparentize, [:color, :amount]

    alias_method :fade_out, :transparentize
    declare :fade_out, [:color, :amount]

    def lighten(color, amount)
      _adjust(color, amount, :lightness, 0..100, :+, "%")
    end
    declare :lighten, [:color, :amount]

    def darken(color, amount)
      _adjust(color, amount, :lightness, 0..100, :-, "%")
    end
    declare :darken, [:color, :amount]

    def saturate(color, amount = nil)
      return identifier("saturate(#{color})") if amount.nil?
      _adjust(color, amount, :saturation, 0..100, :+, "%")
    end
    declare :saturate, [:color, :amount]
    declare :saturate, [:amount]

    def desaturate(color, amount)
      _adjust(color, amount, :saturation, 0..100, :-, "%")
    end
    declare :desaturate, [:color, :amount]

    def adjust_hue(color, degrees)
      assert_type color, :Color, :color
      assert_type degrees, :Number, :degrees
      color.with(:hue => color.hue + degrees.value)
    end
    declare :adjust_hue, [:color, :degrees]

    def ie_hex_str(color)
      assert_type color, :Color, :color
      alpha = Sass::Util.round(color.alpha * 255).to_s(16).rjust(2, '0')
      #nodyna <send-3032> <SD EASY (private access)>
      identifier("##{alpha}#{color.send(:hex_str)[1..-1]}".upcase)
    end
    declare :ie_hex_str, [:color]

    def adjust_color(color, kwargs)
      assert_type color, :Color, :color
      with = Sass::Util.map_hash(
          "red" => [-255..255, ""],
          "green" => [-255..255, ""],
          "blue" => [-255..255, ""],
          "hue" => nil,
          "saturation" => [-100..100, "%"],
          "lightness" => [-100..100, "%"],
          "alpha" => [-1..1, ""]
        ) do |name, (range, units)|

        val = kwargs.delete(name)
        next unless val
        assert_type val, :Number, name
        Sass::Util.check_range("$#{name}: Amount", range, val, units) if range
        #nodyna <send-3033> <SD MODERATE (array)>
        adjusted = color.send(name) + val.value
        adjusted = [0, Sass::Util.restrict(adjusted, range)].max if range
        [name.to_sym, adjusted]
      end

      unless kwargs.empty?
        name, val = kwargs.to_a.first
        raise ArgumentError.new("Unknown argument $#{name} (#{val})")
      end

      color.with(with)
    end
    declare :adjust_color, [:color], :var_kwargs => true

    def scale_color(color, kwargs)
      assert_type color, :Color, :color
      with = Sass::Util.map_hash(
          "red" => 255,
          "green" => 255,
          "blue" => 255,
          "saturation" => 100,
          "lightness" => 100,
          "alpha" => 1
        ) do |name, max|

        val = kwargs.delete(name)
        next unless val
        assert_type val, :Number, name
        assert_unit val, '%', name
        Sass::Util.check_range("$#{name}: Amount", -100..100, val, '%')

        #nodyna <send-3034> <SD MODERATE (array)>
        current = color.send(name)
        scale = val.value / 100.0
        diff = scale > 0 ? max - current : current
        [name.to_sym, current + diff * scale]
      end

      unless kwargs.empty?
        name, val = kwargs.to_a.first
        raise ArgumentError.new("Unknown argument $#{name} (#{val})")
      end

      color.with(with)
    end
    declare :scale_color, [:color], :var_kwargs => true

    def change_color(color, kwargs)
      assert_type color, :Color, :color
      with = Sass::Util.map_hash(
        'red' => ['Red value', 0..255],
        'green' => ['Green value', 0..255],
        'blue' => ['Blue value', 0..255],
        'hue' => [],
        'saturation' => ['Saturation', 0..100, '%'],
        'lightness' => ['Lightness', 0..100, '%'],
        'alpha' => ['Alpha channel', 0..1]
      ) do |name, (desc, range, unit)|
        val = kwargs.delete(name)
        next unless val
        assert_type val, :Number, name

        if range
          val = Sass::Util.check_range(desc, range, val, unit)
        else
          val = val.value
        end

        [name.to_sym, val]
      end

      unless kwargs.empty?
        name, val = kwargs.to_a.first
        raise ArgumentError.new("Unknown argument $#{name} (#{val})")
      end

      color.with(with)
    end
    declare :change_color, [:color], :var_kwargs => true

    def mix(color1, color2, weight = number(50))
      assert_type color1, :Color, :color1
      assert_type color2, :Color, :color2
      assert_type weight, :Number, :weight

      Sass::Util.check_range("Weight", 0..100, weight, '%')

      p = (weight.value / 100.0).to_f
      w = p * 2 - 1
      a = color1.alpha - color2.alpha

      w1 = ((w * a == -1 ? w : (w + a) / (1 + w * a)) + 1) / 2.0
      w2 = 1 - w1

      rgba = color1.rgb.zip(color2.rgb).map {|v1, v2| v1 * w1 + v2 * w2}
      rgba << color1.alpha * p + color2.alpha * (1 - p)
      rgb_color(*rgba)
    end
    declare :mix, [:color1, :color2]
    declare :mix, [:color1, :color2, :weight]

    def grayscale(color)
      if color.is_a?(Sass::Script::Value::Number)
        return identifier("grayscale(#{color})")
      end
      desaturate color, number(100)
    end
    declare :grayscale, [:color]

    def complement(color)
      adjust_hue color, number(180)
    end
    declare :complement, [:color]

    def invert(color)
      if color.is_a?(Sass::Script::Value::Number)
        return identifier("invert(#{color})")
      end

      assert_type color, :Color, :color
      color.with(
        :red => (255 - color.red),
        :green => (255 - color.green),
        :blue => (255 - color.blue))
    end
    declare :invert, [:color]

    def unquote(string)
      unless string.is_a?(Sass::Script::Value::String)
        $_sass_warned_for_unquote ||= Set.new
        frame = environment.stack.frames.last
        key = [frame.filename, frame.line] if frame
        return string if frame && $_sass_warned_for_unquote.include?(key)
        $_sass_warned_for_unquote << key if frame

        Sass::Util.sass_warn(<<MESSAGE.strip)
DEPRECATION WARNING: Passing #{string.to_sass}, a non-string value, to unquote()
will be an error in future versions of Sass.
MESSAGE
        return string
      end

      return string if string.type == :identifier
      identifier(string.value)
    end
    declare :unquote, [:string]

    def quote(string)
      assert_type string, :String, :string
      if string.type != :string
        quoted_string(string.value)
      else
        string
      end
    end
    declare :quote, [:string]

    def str_length(string)
      assert_type string, :String, :string
      number(string.value.size)
    end
    declare :str_length, [:string]

    def str_insert(original, insert, index)
      assert_type original, :String, :string
      assert_type insert, :String, :insert
      assert_integer index, :index
      assert_unit index, nil, :index
      insertion_point = if index.to_i > 0
                          [index.to_i - 1, original.value.size].min
                        else
                          [index.to_i, -original.value.size - 1].max
                        end
      result = original.value.dup.insert(insertion_point, insert.value)
      Sass::Script::Value::String.new(result, original.type)
    end
    declare :str_insert, [:string, :insert, :index]

    def str_index(string, substring)
      assert_type string, :String, :string
      assert_type substring, :String, :substring
      index = string.value.index(substring.value)
      index ? number(index + 1) : null
    end
    declare :str_index, [:string, :substring]

    def str_slice(string, start_at, end_at = nil)
      assert_type string, :String, :string
      assert_unit start_at, nil, "start-at"

      end_at = number(-1) if end_at.nil?
      assert_unit end_at, nil, "end-at"

      return Sass::Script::Value::String.new("", string.type) if end_at.value == 0
      s = start_at.value > 0 ? start_at.value - 1 : start_at.value
      e = end_at.value > 0 ? end_at.value - 1 : end_at.value
      s = string.value.length + s if s < 0
      s = 0 if s < 0
      e = string.value.length + e if e < 0
      e = 0 if s < 0
      extracted = string.value.slice(s..e)
      Sass::Script::Value::String.new(extracted || "", string.type)
    end
    declare :str_slice, [:string, :start_at]
    declare :str_slice, [:string, :start_at, :end_at]

    def to_upper_case(string)
      assert_type string, :String, :string
      Sass::Script::Value::String.new(string.value.upcase, string.type)
    end
    declare :to_upper_case, [:string]

    def to_lower_case(string)
      assert_type string, :String, :string
      Sass::Script::Value::String.new(string.value.downcase, string.type)
    end
    declare :to_lower_case, [:string]

    def type_of(value)
      identifier(value.class.name.gsub(/Sass::Script::Value::/, '').downcase)
    end
    declare :type_of, [:value]

    def feature_exists(feature)
      assert_type feature, :String, :feature
      bool(Sass.has_feature?(feature.value))
    end
    declare :feature_exists, [:feature]

    def unit(number)
      assert_type number, :Number, :number
      quoted_string(number.unit_str)
    end
    declare :unit, [:number]

    def unitless(number)
      assert_type number, :Number, :number
      bool(number.unitless?)
    end
    declare :unitless, [:number]

    def comparable(number1, number2)
      assert_type number1, :Number, :number1
      assert_type number2, :Number, :number2
      bool(number1.comparable_to?(number2))
    end
    declare :comparable, [:number1, :number2]

    def percentage(number)
      unless number.is_a?(Sass::Script::Value::Number) && number.unitless?
        raise ArgumentError.new("$number: #{number.inspect} is not a unitless number")
      end
      number(number.value * 100, '%')
    end
    declare :percentage, [:number]

    def round(number)
      numeric_transformation(number) {|n| Sass::Util.round(n)}
    end
    declare :round, [:number]

    def ceil(number)
      numeric_transformation(number) {|n| n.ceil}
    end
    declare :ceil, [:number]

    def floor(number)
      numeric_transformation(number) {|n| n.floor}
    end
    declare :floor, [:number]

    def abs(number)
      numeric_transformation(number) {|n| n.abs}
    end
    declare :abs, [:number]

    def min(*numbers)
      numbers.each {|n| assert_type n, :Number}
      numbers.inject {|min, num| min.lt(num).to_bool ? min : num}
    end
    declare :min, [], :var_args => :true

    def max(*values)
      values.each {|v| assert_type v, :Number}
      values.inject {|max, val| max.gt(val).to_bool ? max : val}
    end
    declare :max, [], :var_args => :true

    def length(list)
      number(list.to_a.size)
    end
    declare :length, [:list]

    def set_nth(list, n, value)
      assert_type n, :Number, :n
      Sass::Script::Value::List.assert_valid_index(list, n)
      index = n.to_i > 0 ? n.to_i - 1 : n.to_i
      new_list = list.to_a.dup
      new_list[index] = value
      Sass::Script::Value::List.new(new_list, list.separator)
    end
    declare :set_nth, [:list, :n, :value]

    def nth(list, n)
      assert_type n, :Number, :n
      Sass::Script::Value::List.assert_valid_index(list, n)

      index = n.to_i > 0 ? n.to_i - 1 : n.to_i
      list.to_a[index]
    end
    declare :nth, [:list, :n]

    def join(list1, list2, separator = identifier("auto"))
      assert_type separator, :String, :separator
      unless %w[auto space comma].include?(separator.value)
        raise ArgumentError.new("Separator name must be space, comma, or auto")
      end
      sep = if separator.value == 'auto'
              list1.separator || list2.separator || :space
            else
              separator.value.to_sym
            end
      list(list1.to_a + list2.to_a, sep)
    end
    declare :join, [:list1, :list2]
    declare :join, [:list1, :list2, :separator]

    def append(list, val, separator = identifier("auto"))
      assert_type separator, :String, :separator
      unless %w[auto space comma].include?(separator.value)
        raise ArgumentError.new("Separator name must be space, comma, or auto")
      end
      sep = if separator.value == 'auto'
              list.separator || :space
            else
              separator.value.to_sym
            end
      list(list.to_a + [val], sep)
    end
    declare :append, [:list, :val]
    declare :append, [:list, :val, :separator]

    def zip(*lists)
      length = nil
      values = []
      lists.each do |list|
        array = list.to_a
        values << array.dup
        length = length.nil? ? array.length : [length, array.length].min
      end
      values.each do |value|
        value.slice!(length)
      end
      new_list_value = values.first.zip(*values[1..-1])
      list(new_list_value.map {|list| list(list, :space)}, :comma)
    end
    declare :zip, [], :var_args => true

    def index(list, value)
      index = list.to_a.index {|e| e.eq(value).to_bool}
      index ? number(index + 1) : null
    end
    declare :index, [:list, :value]

    def list_separator(list)
      identifier((list.separator || :space).to_s)
    end
    declare :separator, [:list]

    def map_get(map, key)
      assert_type map, :Map, :map
      map.to_h[key] || null
    end
    declare :map_get, [:map, :key]

    def map_merge(map1, map2)
      assert_type map1, :Map, :map1
      assert_type map2, :Map, :map2
      map(map1.to_h.merge(map2.to_h))
    end
    declare :map_merge, [:map1, :map2]

    def map_remove(map, *keys)
      assert_type map, :Map, :map
      hash = map.to_h.dup
      hash.delete_if {|key, _| keys.include?(key)}
      map(hash)
    end
    declare :map_remove, [:map, :key], :var_args => true

    def map_keys(map)
      assert_type map, :Map, :map
      list(map.to_h.keys, :comma)
    end
    declare :map_keys, [:map]

    def map_values(map)
      assert_type map, :Map, :map
      list(map.to_h.values, :comma)
    end
    declare :map_values, [:map]

    def map_has_key(map, key)
      assert_type map, :Map, :map
      bool(map.to_h.has_key?(key))
    end
    declare :map_has_key, [:map, :key]

    def keywords(args)
      assert_type args, :ArgList, :args
      map(Sass::Util.map_keys(args.keywords.as_stored) {|k| Sass::Script::Value::String.new(k)})
    end
    declare :keywords, [:args]

    def if(condition, if_true, if_false)
      if condition.to_bool
        perform(if_true)
      else
        perform(if_false)
      end
    end
    declare :if, [:condition, :"&if_true", :"&if_false"]

    def unique_id
      generator = Sass::Script::Functions.random_number_generator
      Thread.current[:sass_last_unique_id] ||= generator.rand(36**8)
      value = (Thread.current[:sass_last_unique_id] += (generator.rand(10) + 1))
      identifier("u" + value.to_s(36).rjust(8, '0'))
    end
    declare :unique_id, []

    def call(name, *args)
      assert_type name, :String, :name
      kwargs = args.last.is_a?(Hash) ? args.pop : {}
      funcall = Sass::Script::Tree::Funcall.new(
        name.value,
        args.map {|a| Sass::Script::Tree::Literal.new(a)},
        Sass::Util.map_vals(kwargs) {|v| Sass::Script::Tree::Literal.new(v)},
        nil,
        nil)
      funcall.options = options
      perform(funcall)
    end
    declare :call, [:name], :var_args => true, :var_kwargs => true

    def counter(*args)
      identifier("counter(#{args.map {|a| a.to_s(options)}.join(',')})")
    end
    declare :counter, [], :var_args => true

    def counters(*args)
      identifier("counters(#{args.map {|a| a.to_s(options)}.join(',')})")
    end
    declare :counters, [], :var_args => true

    def variable_exists(name)
      assert_type name, :String, :name
      bool(environment.caller.var(name.value))
    end
    declare :variable_exists, [:name]

    def global_variable_exists(name)
      assert_type name, :String, :name
      bool(environment.global_env.var(name.value))
    end
    declare :global_variable_exists, [:name]

    def function_exists(name)
      assert_type name, :String, :name
      exists = Sass::Script::Functions.callable?(name.value.tr("-", "_"))
      exists ||= environment.function(name.value)
      bool(exists)
    end
    declare :function_exists, [:name]

    def mixin_exists(name)
      assert_type name, :String, :name
      bool(environment.mixin(name.value))
    end
    declare :mixin_exists, [:name]

    def inspect(value)
      unquoted_string(value.to_sass)
    end
    declare :inspect, [:value]

    def random(limit = nil)
      generator = Sass::Script::Functions.random_number_generator
      if limit
        assert_integer limit, "limit"
        if limit.to_i < 1
          raise ArgumentError.new("$limit #{limit} must be greater than or equal to 1")
        end
        number(1 + generator.rand(limit.to_i))
      else
        number(generator.rand)
      end
    end
    declare :random, []
    declare :random, [:limit]

    def selector_parse(selector)
      parse_selector(selector, :selector).to_sass_script
    end
    declare :selector_parse, [:selector]

    def selector_nest(*selectors)
      if selectors.empty?
        raise ArgumentError.new("$selectors: At least one selector must be passed")
      end

      parsed = [parse_selector(selectors.first, :selectors)]
      parsed += selectors[1..-1].map {|sel| parse_selector(sel, :selectors, !!:parse_parent_ref)}
      parsed.inject {|result, child| child.resolve_parent_refs(result)}.to_sass_script
    end
    declare :selector_nest, [], :var_args => true

    def selector_append(*selectors)
      if selectors.empty?
        raise ArgumentError.new("$selectors: At least one selector must be passed")
      end

      selectors.map {|sel| parse_selector(sel, :selectors)}.inject do |parent, child|
        child.members.each do |seq|
          sseq = seq.members.first
          unless sseq.is_a?(Sass::Selector::SimpleSequence)
            raise ArgumentError.new("Can't append \"#{seq}\" to \"#{parent}\"")
          end

          base = sseq.base
          case base
          when Sass::Selector::Universal
            raise ArgumentError.new("Can't append \"#{seq}\" to \"#{parent}\"")
          when Sass::Selector::Element
            unless base.namespace.nil?
              raise ArgumentError.new("Can't append \"#{seq}\" to \"#{parent}\"")
            end
            sseq.members[0] = Sass::Selector::Parent.new(base.name)
          else
            sseq.members.unshift Sass::Selector::Parent.new
          end
        end
        child.resolve_parent_refs(parent)
      end.to_sass_script
    end
    declare :selector_append, [], :var_args => true

    def selector_extend(selector, extendee, extender)
      selector = parse_selector(selector, :selector)
      extendee = parse_selector(extendee, :extendee)
      extender = parse_selector(extender, :extender)

      extends = Sass::Util::SubsetMap.new
      begin
        extender.populate_extends(extends, extendee)
        selector.do_extend(extends).to_sass_script
      rescue Sass::SyntaxError => e
        raise ArgumentError.new(e.to_s)
      end
    end
    declare :selector_extend, [:selector, :extendee, :extender]

    def selector_replace(selector, original, replacement)
      selector = parse_selector(selector, :selector)
      original = parse_selector(original, :original)
      replacement = parse_selector(replacement, :replacement)

      extends = Sass::Util::SubsetMap.new
      begin
        replacement.populate_extends(extends, original)
        selector.do_extend(extends, [], !!:replace).to_sass_script
      rescue Sass::SyntaxError => e
        raise ArgumentError.new(e.to_s)
      end
    end
    declare :selector_replace, [:selector, :original, :replacement]

    def selector_unify(selector1, selector2)
      selector1 = parse_selector(selector1, :selector1)
      selector2 = parse_selector(selector2, :selector2)
      return null unless (unified = selector1.unify(selector2))
      unified.to_sass_script
    end
    declare :selector_unify, [:selector1, :selector2]

    def simple_selectors(selector)
      selector = parse_compound_selector(selector, :selector)
      list(selector.members.map {|simple| unquoted_string(simple.to_s)}, :comma)
    end
    declare :simple_selectors, [:selector]

    def is_superselector(sup, sub)
      sup = parse_selector(sup, :super)
      sub = parse_selector(sub, :sub)
      bool(sup.superselector?(sub))
    end
    declare :is_superselector, [:super, :sub]

    private

    def numeric_transformation(value)
      assert_type value, :Number, :value
      Sass::Script::Value::Number.new(
        yield(value.value), value.numerator_units, value.denominator_units)
    end

    def _adjust(color, amount, attr, range, op, units = "")
      assert_type color, :Color, :color
      assert_type amount, :Number, :amount
      Sass::Util.check_range('Amount', range, amount, units)

      #nodyna <send-3035> <SD MODERATE (change-prone variables)>
      #nodyna <send-3036> <SD COMPLEX (change-prone variables)>
      color.with(attr => color.send(attr).send(op, amount.value))
    end

    def check_alpha_unit(alpha, function)
      return if alpha.unitless?

      if alpha.is_unit?("%")
        Sass::Util.sass_warn(<<WARNING)
DEPRECATION WARNING: Passing a percentage as the alpha value to #{function}() will be
interpreted differently in future versions of Sass. For now, use #{alpha.value} instead.
WARNING
      else
        Sass::Util.sass_warn(<<WARNING)
DEPRECATION WARNING: Passing a number with units as the alpha value to #{function}() is
deprecated and will be an error in future versions of Sass. Use #{alpha.value} instead.
WARNING
      end
    end
  end
end
