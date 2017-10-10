class Integer < Numeric
  def to_d
    BigDecimal(self)
  end
end

class Float < Numeric
  def to_d(precision=nil)
    BigDecimal(self, precision || Float::DIG)
  end
end

class String
  def to_d
    BigDecimal(self)
  end
end

class BigDecimal < Numeric
  def to_digits
    if self.nan? || self.infinite? || self.zero?
      self.to_s
    else
      i       = self.to_i.to_s
      _,f,_,z = self.frac.split
      i + "." + ("0"*(-z)) + f
    end
  end

  def to_d
    self
  end
end

class Rational < Numeric
  def to_d(precision)
    if precision <= 0
      raise ArgumentError, "negative precision"
    end
    num = self.numerator
    BigDecimal(num).div(self.denominator, precision)
  end
end
