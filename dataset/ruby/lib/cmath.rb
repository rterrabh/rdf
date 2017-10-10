
module CMath

  include Math

  alias exp! exp
  alias log! log
  alias log2! log2
  alias log10! log10
  alias sqrt! sqrt
  alias cbrt! cbrt

  alias sin! sin
  alias cos! cos
  alias tan! tan

  alias sinh! sinh
  alias cosh! cosh
  alias tanh! tanh

  alias asin! asin
  alias acos! acos
  alias atan! atan
  alias atan2! atan2

  alias asinh! asinh
  alias acosh! acosh
  alias atanh! atanh

  def exp(z)
    begin
      if z.real?
        exp!(z)
      else
        ere = exp!(z.real)
        Complex(ere * cos!(z.imag),
                ere * sin!(z.imag))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def log(*args)
    begin
      z, b = args
      unless b.nil? || b.kind_of?(Numeric)
        raise TypeError,  "Numeric Number required"
      end
      if z.real? and z >= 0 and (b.nil? or b >= 0)
        log!(*args)
      else
        a = Complex(log!(z.abs), z.arg)
        if b
          a /= log(b)
        end
        a
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def log2(z)
    begin
      if z.real? and z >= 0
        log2!(z)
      else
        log(z) / log!(2)
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def log10(z)
    begin
      if z.real? and z >= 0
        log10!(z)
      else
        log(z) / log!(10)
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def sqrt(z)
    begin
      if z.real?
        if z < 0
          Complex(0, sqrt!(-z))
        else
          sqrt!(z)
        end
      else
        if z.imag < 0 ||
            (z.imag == 0 && z.imag.to_s[0] == '-')
          sqrt(z.conjugate).conjugate
        else
          r = z.abs
          x = z.real
          Complex(sqrt!((r + x) / 2.0), sqrt!((r - x) / 2.0))
        end
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def cbrt(z)
    z ** (1.0/3)
  end

  def sin(z)
    begin
      if z.real?
        sin!(z)
      else
        Complex(sin!(z.real) * cosh!(z.imag),
                cos!(z.real) * sinh!(z.imag))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def cos(z)
    begin
      if z.real?
        cos!(z)
      else
        Complex(cos!(z.real) * cosh!(z.imag),
                -sin!(z.real) * sinh!(z.imag))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def tan(z)
    begin
      if z.real?
        tan!(z)
      else
        sin(z) / cos(z)
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def sinh(z)
    begin
      if z.real?
        sinh!(z)
      else
        Complex(sinh!(z.real) * cos!(z.imag),
                cosh!(z.real) * sin!(z.imag))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def cosh(z)
    begin
      if z.real?
        cosh!(z)
      else
        Complex(cosh!(z.real) * cos!(z.imag),
                sinh!(z.real) * sin!(z.imag))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def tanh(z)
    begin
      if z.real?
        tanh!(z)
      else
        sinh(z) / cosh(z)
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def asin(z)
    begin
      if z.real? and z >= -1 and z <= 1
        asin!(z)
      else
        (-1.0).i * log(1.0.i * z + sqrt(1.0 - z * z))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def acos(z)
    begin
      if z.real? and z >= -1 and z <= 1
        acos!(z)
      else
        (-1.0).i * log(z + 1.0.i * sqrt(1.0 - z * z))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def atan(z)
    begin
      if z.real?
        atan!(z)
      else
        1.0.i * log((1.0.i + z) / (1.0.i - z)) / 2.0
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def atan2(y,x)
    begin
      if y.real? and x.real?
        atan2!(y,x)
      else
        (-1.0).i * log((x + 1.0.i * y) / sqrt(x * x + y * y))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def asinh(z)
    begin
      if z.real?
        asinh!(z)
      else
        log(z + sqrt(1.0 + z * z))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def acosh(z)
    begin
      if z.real? and z >= 1
        acosh!(z)
      else
        log(z + sqrt(z * z - 1.0))
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  def atanh(z)
    begin
      if z.real? and z >= -1 and z <= 1
        atanh!(z)
      else
        log((1.0 + z) / (1.0 - z)) / 2.0
      end
    rescue NoMethodError
      handle_no_method_error
    end
  end

  module_function :exp!
  module_function :exp
  module_function :log!
  module_function :log
  module_function :log2!
  module_function :log2
  module_function :log10!
  module_function :log10
  module_function :sqrt!
  module_function :sqrt
  module_function :cbrt!
  module_function :cbrt

  module_function :sin!
  module_function :sin
  module_function :cos!
  module_function :cos
  module_function :tan!
  module_function :tan

  module_function :sinh!
  module_function :sinh
  module_function :cosh!
  module_function :cosh
  module_function :tanh!
  module_function :tanh

  module_function :asin!
  module_function :asin
  module_function :acos!
  module_function :acos
  module_function :atan!
  module_function :atan
  module_function :atan2!
  module_function :atan2

  module_function :asinh!
  module_function :asinh
  module_function :acosh!
  module_function :acosh
  module_function :atanh!
  module_function :atanh

  module_function :frexp
  module_function :ldexp
  module_function :hypot
  module_function :erf
  module_function :erfc
  module_function :gamma
  module_function :lgamma

  private
  def handle_no_method_error # :nodoc:
    if $!.name == :real?
      raise TypeError, "Numeric Number required"
    else
      raise
    end
  end
  module_function :handle_no_method_error

end
