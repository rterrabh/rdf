

warn('lib/mathn.rb is deprecated') if $VERBOSE

class Numeric; end

require "cmath.rb"
require "matrix.rb"
require "prime.rb"

require "mathn/rational"
require "mathn/complex"

unless defined?(Math.exp!)
  #nodyna <instance_eval-2352> <IEV MODERATE (private access)>
  Object.instance_eval{remove_const :Math}
  Math = CMath # :nodoc:
end


class Fixnum
  remove_method :/


  alias / quo
end


class Bignum
  remove_method :/


  alias / quo
end


module Math
  remove_method(:sqrt)


  def sqrt(a)
    if a.kind_of?(Complex)
      abs = sqrt(a.real*a.real + a.imag*a.imag)
      x = sqrt((a.real + abs)/Rational(2))
      y = sqrt((-a.real + abs)/Rational(2))
      if a.imag >= 0
        Complex(x, y)
      else
        Complex(x, -y)
      end
    elsif a.respond_to?(:nan?) and a.nan?
      a
    elsif a >= 0
      rsqrt(a)
    else
      Complex(0,rsqrt(-a))
    end
  end


  def rsqrt(a)
    if a.kind_of?(Float)
      sqrt!(a)
    elsif a.kind_of?(Rational)
      rsqrt(a.numerator)/rsqrt(a.denominator)
    else
      src = a
      max = 2 ** 32
      byte_a = [src & 0xffffffff]
      while (src >= max) and (src >>= 32)
        byte_a.unshift src & 0xffffffff
      end

      answer = 0
      main = 0
      side = 0
      for elm in byte_a
        main = (main << 32) + elm
        side <<= 16
        if answer != 0
          if main * 4  < side * side
            applo = main.div(side)
          else
            applo = ((sqrt!(side * side + 4 * main) - side)/2.0).to_i + 1
          end
        else
          applo = sqrt!(main).to_i + 1
        end

        while (x = (side + applo) * applo) > main
          applo -= 1
        end
        main -= x
        answer = (answer << 16) + applo
        side += applo * 2
      end
      if main == 0
        answer
      else
        sqrt!(a)
      end
    end
  end

  class << self
    remove_method(:sqrt)
  end
  module_function :sqrt
  module_function :rsqrt
end
