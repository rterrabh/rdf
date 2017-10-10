require 'bigdecimal'

module BigMath
  module_function

  def sqrt(x, prec)
    x.sqrt(prec)
  end

  def sin(x, prec)
    raise ArgumentError, "Zero or negative precision for sin" if prec <= 0
    return BigDecimal("NaN") if x.infinite? || x.nan?
    n    = prec + BigDecimal.double_fig
    one  = BigDecimal("1")
    two  = BigDecimal("2")
    x = -x if neg = x < 0
    if x > (twopi = two * BigMath.PI(prec))
      if x > 30
        x %= twopi
      else
        x -= twopi while x > twopi
      end
    end
    x1   = x
    x2   = x.mult(x,n)
    sign = 1
    y    = x
    d    = y
    i    = one
    z    = one
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      sign = -sign
      x1  = x2.mult(x1,n)
      i  += two
      z  *= (i-one) * i
      d   = sign * x1.div(z,m)
      y  += d
    end
    neg ? -y : y
  end

  def cos(x, prec)
    raise ArgumentError, "Zero or negative precision for cos" if prec <= 0
    return BigDecimal("NaN") if x.infinite? || x.nan?
    n    = prec + BigDecimal.double_fig
    one  = BigDecimal("1")
    two  = BigDecimal("2")
    x = -x if x < 0
    if x > (twopi = two * BigMath.PI(prec))
      if x > 30
        x %= twopi
      else
        x -= twopi while x > twopi
      end
    end
    x1 = one
    x2 = x.mult(x,n)
    sign = 1
    y = one
    d = y
    i = BigDecimal("0")
    z = one
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      sign = -sign
      x1  = x2.mult(x1,n)
      i  += two
      z  *= (i-one) * i
      d   = sign * x1.div(z,m)
      y  += d
    end
    y
  end

  def atan(x, prec)
    raise ArgumentError, "Zero or negative precision for atan" if prec <= 0
    return BigDecimal("NaN") if x.nan?
    pi = PI(prec)
    x = -x if neg = x < 0
    return pi.div(neg ? -2 : 2, prec) if x.infinite?
    return pi / (neg ? -4 : 4) if x.round(prec) == 1
    x = BigDecimal("1").div(x, prec) if inv = x > 1
    x = (-1 + sqrt(1 + x**2, prec))/x if dbl = x > 0.5
    n    = prec + BigDecimal.double_fig
    y = x
    d = y
    t = x
    r = BigDecimal("3")
    x2 = x.mult(x,n)
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t = -t.mult(x2,n)
      d = t.div(r,m)
      y += d
      r += 2
    end
    y *= 2 if dbl
    y = pi / 2 - y if inv
    y = -y if neg
    y
  end

  def PI(prec)
    raise ArgumentError, "Zero or negative precision for PI" if prec <= 0
    n      = prec + BigDecimal.double_fig
    zero   = BigDecimal("0")
    one    = BigDecimal("1")
    two    = BigDecimal("2")

    m25    = BigDecimal("-0.04")
    m57121 = BigDecimal("-57121")

    pi     = zero

    d = one
    k = one
    t = BigDecimal("-80")
    while d.nonzero? && ((m = n - (pi.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t   = t*m25
      d   = t.div(k,m)
      k   = k+two
      pi  = pi + d
    end

    d = one
    k = one
    t = BigDecimal("956")
    while d.nonzero? && ((m = n - (pi.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t   = t.div(m57121,n)
      d   = t.div(k,m)
      pi  = pi + d
      k   = k+two
    end
    pi
  end

  def E(prec)
    raise ArgumentError, "Zero or negative precision for E" if prec <= 0
    BigMath.exp(1, prec)
  end
end
