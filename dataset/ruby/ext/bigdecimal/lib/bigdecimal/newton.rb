require "bigdecimal/ludcmp"
require "bigdecimal/jacobian"

module Newton
  include LUSolve
  include Jacobian
  module_function

  def norm(fv,zero=0.0) # :nodoc:
    s = zero
    n = fv.size
    for i in 0...n do
      s += fv[i]*fv[i]
    end
    s
  end

  def nlsolve(f,x)
    nRetry = 0
    n = x.size

    f0 = f.values(x)
    zero = f.zero
    one  = f.one
    two  = f.two
    p5 = one/two
    d  = norm(f0,zero)
    minfact = f.ten*f.ten*f.ten
    minfact = one/minfact
    e = f.eps
    while d >= e do
      nRetry += 1
      dfdx = jacobian(f,f0,x)
      dx = lusolve(dfdx,f0,ludecomp(dfdx,n,zero,one),zero)
      fact = two
      xs = x.dup
      begin
        fact *= p5
        if fact < minfact then
          raise "Failed to reduce function values."
        end
        for i in 0...n do
          x[i] = xs[i] - dx[i]*fact
        end
        f0 = f.values(x)
        dn = norm(f0,zero)
      end while(dn>=d)
      d = dn
    end
    nRetry
  end
end
