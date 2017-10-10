module Sass::Script::Value
  class Number < Base
    attr_reader :value

    attr_reader :numerator_units

    attr_reader :denominator_units

    attr_accessor :original

    def self.precision
      @precision ||= 5
    end

    def self.precision=(digits)
      @precision = digits.round
      @precision_factor = 10.0**@precision
    end

    def self.precision_factor
      @precision_factor ||= 10.0**precision
    end

    NO_UNITS  = []

    def initialize(value, numerator_units = NO_UNITS, denominator_units = NO_UNITS)
      numerator_units = [numerator_units] if numerator_units.is_a?(::String)
      denominator_units = [denominator_units] if denominator_units.is_a?(::String)
      super(value)
      @numerator_units = numerator_units
      @denominator_units = denominator_units
      normalize!
    end

    def plus(other)
      if other.is_a? Number
        operate(other, :+)
      elsif other.is_a?(Color)
        other.plus(self)
      else
        super
      end
    end

    def minus(other)
      if other.is_a? Number
        operate(other, :-)
      else
        super
      end
    end

    def unary_plus
      self
    end

    def unary_minus
      Number.new(-value, @numerator_units, @denominator_units)
    end

    def times(other)
      if other.is_a? Number
        operate(other, :*)
      elsif other.is_a? Color
        other.times(self)
      else
        raise NoMethodError.new(nil, :times)
      end
    end

    def div(other)
      if other.is_a? Number
        res = operate(other, :/)
        if original && other.original
          res.original = "#{original}/#{other.original}"
        end
        res
      else
        super
      end
    end

    def mod(other)
      if other.is_a?(Number)
        operate(other, :%)
      else
        raise NoMethodError.new(nil, :mod)
      end
    end

    def eq(other)
      return Bool::FALSE unless other.is_a?(Sass::Script::Value::Number)
      this = self
      begin
        if unitless?
          this = this.coerce(other.numerator_units, other.denominator_units)
        else
          other = other.coerce(@numerator_units, @denominator_units)
        end
      rescue Sass::UnitConversionError
        return Bool::FALSE
      end
      Bool.new(this.value == other.value)
    end

    def hash
      [value, numerator_units, denominator_units].hash
    end

    def eql?(other)
      value == other.value && numerator_units == other.numerator_units &&
        denominator_units == other.denominator_units
    end

    def gt(other)
      raise NoMethodError.new(nil, :gt) unless other.is_a?(Number)
      operate(other, :>)
    end

    def gte(other)
      raise NoMethodError.new(nil, :gte) unless other.is_a?(Number)
      operate(other, :>=)
    end

    def lt(other)
      raise NoMethodError.new(nil, :lt) unless other.is_a?(Number)
      operate(other, :<)
    end

    def lte(other)
      raise NoMethodError.new(nil, :lte) unless other.is_a?(Number)
      operate(other, :<=)
    end

    def to_s(opts = {})
      return original if original
      raise Sass::SyntaxError.new("#{inspect} isn't a valid CSS value.") unless legal_units?
      inspect
    end

    def inspect(opts = {})
      return original if original

      value = self.class.round(self.value)
      str = value.to_s

      str = ("%0.#{self.class.precision}f" % value).gsub(/0*$/, '') if str.include?('e')

      unitless? ? str : "#{str}#{unit_str}"
    end
    alias_method :to_sass, :inspect

    def to_i
      super unless int?
      value.to_i
    end

    def int?
      value % 1 == 0.0
    end

    def unitless?
      @numerator_units.empty? && @denominator_units.empty?
    end

    def is_unit?(unit)
      if unit
        denominator_units.size == 0 && numerator_units.size == 1 && numerator_units.first == unit
      else
        unitless?
      end
    end

    def legal_units?
      (@numerator_units.empty? || @numerator_units.size == 1) && @denominator_units.empty?
    end

    def coerce(num_units, den_units)
      Number.new(if unitless?
                   value
                 else
                   value * coercion_factor(@numerator_units, num_units) /
                     coercion_factor(@denominator_units, den_units)
                 end, num_units, den_units)
    end

    def comparable_to?(other)
      operate(other, :+)
      true
    rescue Sass::UnitConversionError
      false
    end

    def unit_str
      rv = @numerator_units.sort.join("*")
      if @denominator_units.any?
        rv << "/"
        rv << @denominator_units.sort.join("*")
      end
      rv
    end

    private

    def self.round(num)
      if num.is_a?(Float) && (num.infinite? || num.nan?)
        num
      elsif num % 1 == 0.0
        num.to_i
      else
        ((num * precision_factor).round / precision_factor).to_f
      end
    end

    OPERATIONS = [:+, :-, :<=, :<, :>, :>=, :%]

    def operate(other, operation)
      this = self
      if OPERATIONS.include?(operation)
        if unitless?
          this = this.coerce(other.numerator_units, other.denominator_units)
        else
          other = other.coerce(@numerator_units, @denominator_units)
        end
      end
      value = :/ == operation ? this.value.to_f : this.value
      #nodyna <send-3026> <SD MODERATE (change-prone variables)>
      result = value.send(operation, other.value)

      if result.is_a?(Numeric)
        Number.new(result, *compute_units(this, other, operation))
      else # Boolean op
        Bool.new(result)
      end
    end

    def coercion_factor(from_units, to_units)
      from_units, to_units = sans_common_units(from_units, to_units)

      if from_units.size != to_units.size || !convertable?(from_units | to_units)
        raise Sass::UnitConversionError.new(
          "Incompatible units: '#{from_units.join('*')}' and '#{to_units.join('*')}'.")
      end

      from_units.zip(to_units).inject(1) {|m, p| m * conversion_factor(p[0], p[1])}
    end

    def compute_units(this, other, operation)
      case operation
      when :*
        [this.numerator_units + other.numerator_units,
         this.denominator_units + other.denominator_units]
      when :/
        [this.numerator_units + other.denominator_units,
         this.denominator_units + other.numerator_units]
      else
        [this.numerator_units, this.denominator_units]
      end
    end

    def normalize!
      return if unitless?
      @numerator_units, @denominator_units =
        sans_common_units(@numerator_units, @denominator_units)

      @denominator_units.each_with_index do |d, i|
        if convertable?(d) && (u = @numerator_units.find(&method(:convertable?)))
          @value /= conversion_factor(d, u)
          @denominator_units.delete_at(i)
          @numerator_units.delete_at(@numerator_units.index(u))
        end
      end
    end

    relative_sizes = [
      {
        'in' => Rational(1),
        'cm' => Rational(1, 2.54),
        'pc' => Rational(1, 6),
        'mm' => Rational(1, 25.4),
        'pt' => Rational(1, 72),
        'px' => Rational(1, 96)
      },
      {
        'deg'  => Rational(1, 360),
        'grad' => Rational(1, 400),
        'rad'  => Rational(1, 2 * Math::PI),
        'turn' => Rational(1)
      },
      {
        's'  => Rational(1),
        'ms' => Rational(1, 1000)
      },
      {
        'Hz'  => Rational(1),
        'kHz' => Rational(1000)
      },
      {
        'dpi'  => Rational(1),
        'dpcm' => Rational(1, 2.54),
        'dppx' => Rational(1, 96)
      }
    ]

    MUTUALLY_CONVERTIBLE = {}
    relative_sizes.map do |values|
      set = values.keys.to_set
      values.keys.each {|name| MUTUALLY_CONVERTIBLE[name] = set}
    end

    CONVERSION_TABLE = {}
    relative_sizes.each do |values|
      values.each do |(name1, value1)|
        CONVERSION_TABLE[name1] ||= {}
        values.each do |(name2, value2)|
          value = value1 / value2
          CONVERSION_TABLE[name1][name2] = value.denominator == 1 ? value.to_i : value.to_f
        end
      end
    end

    def conversion_factor(from_unit, to_unit)
      CONVERSION_TABLE[from_unit][to_unit]
    end

    def convertable?(units)
      units = Array(units).to_set
      return true if units.empty?
      return false unless (mutually_convertible = MUTUALLY_CONVERTIBLE[units.first])
      units.subset?(mutually_convertible)
    end

    def sans_common_units(units1, units2)
      units2 = units2.dup
      units1 = units1.map do |u|
        j = units2.index(u)
        next u unless j
        units2.delete_at(j)
        nil
      end
      units1.compact!
      return units1, units2
    end
  end
end
