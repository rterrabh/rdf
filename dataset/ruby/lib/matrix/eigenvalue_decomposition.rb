class Matrix


  class EigenvalueDecomposition

    def initialize(a)
      raise TypeError, "Expected Matrix but got #{a.class}" unless a.is_a?(Matrix)
      @size = a.row_count
      @d = Array.new(@size, 0)
      @e = Array.new(@size, 0)

      if (@symmetric = a.symmetric?)
        @v = a.to_a
        tridiagonalize
        diagonalize
      else
        @v = Array.new(@size) { Array.new(@size, 0) }
        @h = a.to_a
        @ort = Array.new(@size, 0)
        reduce_to_hessenberg
        hessenberg_to_real_schur
      end
    end

    def eigenvector_matrix
      #nodyna <send-2004> <SD COMPLEX (private methods)>
      Matrix.send(:new, build_eigenvectors.transpose)
    end
    alias v eigenvector_matrix

    def eigenvector_matrix_inv
      #nodyna <send-2005> <SD COMPLEX (private methods)>
      r = Matrix.send(:new, build_eigenvectors)
      r = r.transpose.inverse unless @symmetric
      r
    end
    alias v_inv eigenvector_matrix_inv

    def eigenvalues
      values = @d.dup
      @e.each_with_index{|imag, i| values[i] = Complex(values[i], imag) unless imag == 0}
      values
    end

    def eigenvectors
      #nodyna <send-2006> <SD COMPLEX (private methods)>
      build_eigenvectors.map{|ev| Vector.send(:new, ev)}
    end

    def eigenvalue_matrix
      Matrix.diagonal(*eigenvalues)
    end
    alias d eigenvalue_matrix

    def to_ary
      [v, d, v_inv]
    end
    alias_method :to_a, :to_ary

  private
    def build_eigenvectors
      @e.each_with_index.map do |imag, i|
        if imag == 0
          Array.new(@size){|j| @v[j][i]}
        elsif imag > 0
          Array.new(@size){|j| Complex(@v[j][i], @v[j][i+1])}
        else
          Array.new(@size){|j| Complex(@v[j][i-1], -@v[j][i])}
        end
      end
    end

    def cdiv(xr, xi, yr, yi)
      if (yr.abs > yi.abs)
        r = yi/yr
        d = yr + r*yi
        [(xr + r*xi)/d, (xi - r*xr)/d]
      else
        r = yr/yi
        d = yi + r*yr
        [(r*xr + xi)/d, (r*xi - xr)/d]
      end
    end



    def tridiagonalize


        @size.times do |j|
          @d[j] = @v[@size-1][j]
        end


        (@size-1).downto(0+1) do |i|


          scale = 0.0
          h = 0.0
          i.times do |k|
            scale = scale + @d[k].abs
          end
          if (scale == 0.0)
            @e[i] = @d[i-1]
            i.times do |j|
              @d[j] = @v[i-1][j]
              @v[i][j] = 0.0
              @v[j][i] = 0.0
            end
          else


            i.times do |k|
              @d[k] /= scale
              h += @d[k] * @d[k]
            end
            f = @d[i-1]
            g = Math.sqrt(h)
            if (f > 0)
              g = -g
            end
            @e[i] = scale * g
            h -= f * g
            @d[i-1] = f - g
            i.times do |j|
              @e[j] = 0.0
            end


            i.times do |j|
              f = @d[j]
              @v[j][i] = f
              g = @e[j] + @v[j][j] * f
              (j+1).upto(i-1) do |k|
                g += @v[k][j] * @d[k]
                @e[k] += @v[k][j] * f
              end
              @e[j] = g
            end
            f = 0.0
            i.times do |j|
              @e[j] /= h
              f += @e[j] * @d[j]
            end
            hh = f / (h + h)
            i.times do |j|
              @e[j] -= hh * @d[j]
            end
            i.times do |j|
              f = @d[j]
              g = @e[j]
              j.upto(i-1) do |k|
                @v[k][j] -= (f * @e[k] + g * @d[k])
              end
              @d[j] = @v[i-1][j]
              @v[i][j] = 0.0
            end
          end
          @d[i] = h
        end


        0.upto(@size-1-1) do |i|
          @v[@size-1][i] = @v[i][i]
          @v[i][i] = 1.0
          h = @d[i+1]
          if (h != 0.0)
            0.upto(i) do |k|
              @d[k] = @v[k][i+1] / h
            end
            0.upto(i) do |j|
              g = 0.0
              0.upto(i) do |k|
                g += @v[k][i+1] * @v[k][j]
              end
              0.upto(i) do |k|
                @v[k][j] -= g * @d[k]
              end
            end
          end
          0.upto(i) do |k|
            @v[k][i+1] = 0.0
          end
        end
        @size.times do |j|
          @d[j] = @v[@size-1][j]
          @v[@size-1][j] = 0.0
        end
        @v[@size-1][@size-1] = 1.0
        @e[0] = 0.0
      end



    def diagonalize

      1.upto(@size-1) do |i|
        @e[i-1] = @e[i]
      end
      @e[@size-1] = 0.0

      f = 0.0
      tst1 = 0.0
      eps = Float::EPSILON
      @size.times do |l|


        tst1 = [tst1, @d[l].abs + @e[l].abs].max
        m = l
        while (m < @size) do
          if (@e[m].abs <= eps*tst1)
            break
          end
          m+=1
        end


        if (m > l)
          iter = 0
          begin
            iter = iter + 1  # (Could check iteration count here.)


            g = @d[l]
            p = (@d[l+1] - g) / (2.0 * @e[l])
            r = Math.hypot(p, 1.0)
            if (p < 0)
              r = -r
            end
            @d[l] = @e[l] / (p + r)
            @d[l+1] = @e[l] * (p + r)
            dl1 = @d[l+1]
            h = g - @d[l]
            (l+2).upto(@size-1) do |i|
              @d[i] -= h
            end
            f += h


            p = @d[m]
            c = 1.0
            c2 = c
            c3 = c
            el1 = @e[l+1]
            s = 0.0
            s2 = 0.0
            (m-1).downto(l) do |i|
              c3 = c2
              c2 = c
              s2 = s
              g = c * @e[i]
              h = c * p
              r = Math.hypot(p, @e[i])
              @e[i+1] = s * r
              s = @e[i] / r
              c = p / r
              p = c * @d[i] - s * g
              @d[i+1] = h + s * (c * g + s * @d[i])


              @size.times do |k|
                h = @v[k][i+1]
                @v[k][i+1] = s * @v[k][i] + c * h
                @v[k][i] = c * @v[k][i] - s * h
              end
            end
            p = -s * s2 * c3 * el1 * @e[l] / dl1
            @e[l] = s * p
            @d[l] = c * p


          end while (@e[l].abs > eps*tst1)
        end
        @d[l] = @d[l] + f
        @e[l] = 0.0
      end


      0.upto(@size-2) do |i|
        k = i
        p = @d[i]
        (i+1).upto(@size-1) do |j|
          if (@d[j] < p)
            k = j
            p = @d[j]
          end
        end
        if (k != i)
          @d[k] = @d[i]
          @d[i] = p
          @size.times do |j|
            p = @v[j][i]
            @v[j][i] = @v[j][k]
            @v[j][k] = p
          end
        end
      end
    end


    def reduce_to_hessenberg

      low = 0
      high = @size-1

      (low+1).upto(high-1) do |m|


        scale = 0.0
        m.upto(high) do |i|
          scale = scale + @h[i][m-1].abs
        end
        if (scale != 0.0)


          h = 0.0
          high.downto(m) do |i|
            @ort[i] = @h[i][m-1]/scale
            h += @ort[i] * @ort[i]
          end
          g = Math.sqrt(h)
          if (@ort[m] > 0)
            g = -g
          end
          h -= @ort[m] * g
          @ort[m] = @ort[m] - g


          m.upto(@size-1) do |j|
            f = 0.0
            high.downto(m) do |i|
              f += @ort[i]*@h[i][j]
            end
            f = f/h
            m.upto(high) do |i|
              @h[i][j] -= f*@ort[i]
            end
          end

          0.upto(high) do |i|
            f = 0.0
            high.downto(m) do |j|
              f += @ort[j]*@h[i][j]
            end
            f = f/h
            m.upto(high) do |j|
              @h[i][j] -= f*@ort[j]
            end
          end
          @ort[m] = scale*@ort[m]
          @h[m][m-1] = scale*g
        end
      end


      @size.times do |i|
        @size.times do |j|
          @v[i][j] = (i == j ? 1.0 : 0.0)
        end
      end

      (high-1).downto(low+1) do |m|
        if (@h[m][m-1] != 0.0)
          (m+1).upto(high) do |i|
            @ort[i] = @h[i][m-1]
          end
          m.upto(high) do |j|
            g = 0.0
            m.upto(high) do |i|
              g += @ort[i] * @v[i][j]
            end
            g = (g / @ort[m]) / @h[m][m-1]
            m.upto(high) do |i|
              @v[i][j] += g * @ort[i]
            end
          end
        end
      end
    end




    def hessenberg_to_real_schur



      nn = @size
      n = nn-1
      low = 0
      high = nn-1
      eps = Float::EPSILON
      exshift = 0.0
      p=q=r=s=z=0


      norm = 0.0
      nn.times do |i|
        if (i < low || i > high)
          @d[i] = @h[i][i]
          @e[i] = 0.0
        end
        ([i-1, 0].max).upto(nn-1) do |j|
          norm = norm + @h[i][j].abs
        end
      end


      iter = 0
      while (n >= low) do


        l = n
        while (l > low) do
          s = @h[l-1][l-1].abs + @h[l][l].abs
          if (s == 0.0)
            s = norm
          end
          if (@h[l][l-1].abs < eps * s)
            break
          end
          l-=1
        end


        if (l == n)
          @h[n][n] = @h[n][n] + exshift
          @d[n] = @h[n][n]
          @e[n] = 0.0
          n-=1
          iter = 0


        elsif (l == n-1)
          w = @h[n][n-1] * @h[n-1][n]
          p = (@h[n-1][n-1] - @h[n][n]) / 2.0
          q = p * p + w
          z = Math.sqrt(q.abs)
          @h[n][n] = @h[n][n] + exshift
          @h[n-1][n-1] = @h[n-1][n-1] + exshift
          x = @h[n][n]


          if (q >= 0)
            if (p >= 0)
              z = p + z
            else
              z = p - z
            end
            @d[n-1] = x + z
            @d[n] = @d[n-1]
            if (z != 0.0)
              @d[n] = x - w / z
            end
            @e[n-1] = 0.0
            @e[n] = 0.0
            x = @h[n][n-1]
            s = x.abs + z.abs
            p = x / s
            q = z / s
            r = Math.sqrt(p * p+q * q)
            p /= r
            q /= r


            (n-1).upto(nn-1) do |j|
              z = @h[n-1][j]
              @h[n-1][j] = q * z + p * @h[n][j]
              @h[n][j] = q * @h[n][j] - p * z
            end


            0.upto(n) do |i|
              z = @h[i][n-1]
              @h[i][n-1] = q * z + p * @h[i][n]
              @h[i][n] = q * @h[i][n] - p * z
            end


            low.upto(high) do |i|
              z = @v[i][n-1]
              @v[i][n-1] = q * z + p * @v[i][n]
              @v[i][n] = q * @v[i][n] - p * z
            end


          else
            @d[n-1] = x + p
            @d[n] = x + p
            @e[n-1] = z
            @e[n] = -z
          end
          n -= 2
          iter = 0


        else


          x = @h[n][n]
          y = 0.0
          w = 0.0
          if (l < n)
            y = @h[n-1][n-1]
            w = @h[n][n-1] * @h[n-1][n]
          end


          if (iter == 10)
            exshift += x
            low.upto(n) do |i|
              @h[i][i] -= x
            end
            s = @h[n][n-1].abs + @h[n-1][n-2].abs
            x = y = 0.75 * s
            w = -0.4375 * s * s
          end


          if (iter == 30)
             s = (y - x) / 2.0
             s *= s + w
             if (s > 0)
                s = Math.sqrt(s)
                if (y < x)
                  s = -s
                end
                s = x - w / ((y - x) / 2.0 + s)
                low.upto(n) do |i|
                  @h[i][i] -= s
                end
                exshift += s
                x = y = w = 0.964
             end
          end

          iter = iter + 1  # (Could check iteration count here.)


          m = n-2
          while (m >= l) do
            z = @h[m][m]
            r = x - z
            s = y - z
            p = (r * s - w) / @h[m+1][m] + @h[m][m+1]
            q = @h[m+1][m+1] - z - r - s
            r = @h[m+2][m+1]
            s = p.abs + q.abs + r.abs
            p /= s
            q /= s
            r /= s
            if (m == l)
              break
            end
            if (@h[m][m-1].abs * (q.abs + r.abs) <
              eps * (p.abs * (@h[m-1][m-1].abs + z.abs +
              @h[m+1][m+1].abs)))
                break
            end
            m-=1
          end

          (m+2).upto(n) do |i|
            @h[i][i-2] = 0.0
            if (i > m+2)
              @h[i][i-3] = 0.0
            end
          end


          m.upto(n-1) do |k|
            notlast = (k != n-1)
            if (k != m)
              p = @h[k][k-1]
              q = @h[k+1][k-1]
              r = (notlast ? @h[k+2][k-1] : 0.0)
              x = p.abs + q.abs + r.abs
              next if x == 0
              p /= x
              q /= x
              r /= x
            end
            s = Math.sqrt(p * p + q * q + r * r)
            if (p < 0)
              s = -s
            end
            if (s != 0)
              if (k != m)
                @h[k][k-1] = -s * x
              elsif (l != m)
                @h[k][k-1] = -@h[k][k-1]
              end
              p += s
              x = p / s
              y = q / s
              z = r / s
              q /= p
              r /= p


              k.upto(nn-1) do |j|
                p = @h[k][j] + q * @h[k+1][j]
                if (notlast)
                  p += r * @h[k+2][j]
                  @h[k+2][j] = @h[k+2][j] - p * z
                end
                @h[k][j] = @h[k][j] - p * x
                @h[k+1][j] = @h[k+1][j] - p * y
              end


              0.upto([n, k+3].min) do |i|
                p = x * @h[i][k] + y * @h[i][k+1]
                if (notlast)
                  p += z * @h[i][k+2]
                  @h[i][k+2] = @h[i][k+2] - p * r
                end
                @h[i][k] = @h[i][k] - p
                @h[i][k+1] = @h[i][k+1] - p * q
              end


              low.upto(high) do |i|
                p = x * @v[i][k] + y * @v[i][k+1]
                if (notlast)
                  p += z * @v[i][k+2]
                  @v[i][k+2] = @v[i][k+2] - p * r
                end
                @v[i][k] = @v[i][k] - p
                @v[i][k+1] = @v[i][k+1] - p * q
              end
            end  # (s != 0)
          end  # k loop
        end  # check convergence
      end  # while (n >= low)


      if (norm == 0.0)
        return
      end

      (nn-1).downto(0) do |n|
        p = @d[n]
        q = @e[n]


        if (q == 0)
          l = n
          @h[n][n] = 1.0
          (n-1).downto(0) do |i|
            w = @h[i][i] - p
            r = 0.0
            l.upto(n) do |j|
              r += @h[i][j] * @h[j][n]
            end
            if (@e[i] < 0.0)
              z = w
              s = r
            else
              l = i
              if (@e[i] == 0.0)
                if (w != 0.0)
                  @h[i][n] = -r / w
                else
                  @h[i][n] = -r / (eps * norm)
                end


              else
                x = @h[i][i+1]
                y = @h[i+1][i]
                q = (@d[i] - p) * (@d[i] - p) + @e[i] * @e[i]
                t = (x * s - z * r) / q
                @h[i][n] = t
                if (x.abs > z.abs)
                  @h[i+1][n] = (-r - w * t) / x
                else
                  @h[i+1][n] = (-s - y * t) / z
                end
              end


              t = @h[i][n].abs
              if ((eps * t) * t > 1)
                i.upto(n) do |j|
                  @h[j][n] = @h[j][n] / t
                end
              end
            end
          end


        elsif (q < 0)
          l = n-1


          if (@h[n][n-1].abs > @h[n-1][n].abs)
            @h[n-1][n-1] = q / @h[n][n-1]
            @h[n-1][n] = -(@h[n][n] - p) / @h[n][n-1]
          else
            cdivr, cdivi = cdiv(0.0, -@h[n-1][n], @h[n-1][n-1]-p, q)
            @h[n-1][n-1] = cdivr
            @h[n-1][n] = cdivi
          end
          @h[n][n-1] = 0.0
          @h[n][n] = 1.0
          (n-2).downto(0) do |i|
            ra = 0.0
            sa = 0.0
            l.upto(n) do |j|
              ra = ra + @h[i][j] * @h[j][n-1]
              sa = sa + @h[i][j] * @h[j][n]
            end
            w = @h[i][i] - p

            if (@e[i] < 0.0)
              z = w
              r = ra
              s = sa
            else
              l = i
              if (@e[i] == 0)
                cdivr, cdivi = cdiv(-ra, -sa, w, q)
                @h[i][n-1] = cdivr
                @h[i][n] = cdivi
              else


                x = @h[i][i+1]
                y = @h[i+1][i]
                vr = (@d[i] - p) * (@d[i] - p) + @e[i] * @e[i] - q * q
                vi = (@d[i] - p) * 2.0 * q
                if (vr == 0.0 && vi == 0.0)
                  vr = eps * norm * (w.abs + q.abs +
                  x.abs + y.abs + z.abs)
                end
                cdivr, cdivi = cdiv(x*r-z*ra+q*sa, x*s-z*sa-q*ra, vr, vi)
                @h[i][n-1] = cdivr
                @h[i][n] = cdivi
                if (x.abs > (z.abs + q.abs))
                  @h[i+1][n-1] = (-ra - w * @h[i][n-1] + q * @h[i][n]) / x
                  @h[i+1][n] = (-sa - w * @h[i][n] - q * @h[i][n-1]) / x
                else
                  cdivr, cdivi = cdiv(-r-y*@h[i][n-1], -s-y*@h[i][n], z, q)
                  @h[i+1][n-1] = cdivr
                  @h[i+1][n] = cdivi
                end
              end


              t = [@h[i][n-1].abs, @h[i][n].abs].max
              if ((eps * t) * t > 1)
                i.upto(n) do |j|
                  @h[j][n-1] = @h[j][n-1] / t
                  @h[j][n] = @h[j][n] / t
                end
              end
            end
          end
        end
      end


      nn.times do |i|
        if (i < low || i > high)
          i.upto(nn-1) do |j|
            @v[i][j] = @h[i][j]
          end
        end
      end


      (nn-1).downto(low) do |j|
        low.upto(high) do |i|
          z = 0.0
          low.upto([j, high].min) do |k|
            z += @v[i][k] * @h[k][j]
          end
          @v[i][j] = z
        end
      end
    end

  end
end
