class Matrix


  class LUPDecomposition

    include Matrix::ConversionHelper

    def l
      Matrix.build(@row_count, [@column_count, @row_count].min) do |i, j|
        if (i > j)
          @lu[i][j]
        elsif (i == j)
          1
        else
          0
        end
      end
    end


    def u
      Matrix.build([@column_count, @row_count].min, @column_count) do |i, j|
        if (i <= j)
          @lu[i][j]
        else
          0
        end
      end
    end


    def p
      rows = Array.new(@row_count){Array.new(@row_count, 0)}
      @pivots.each_with_index{|p, i| rows[i][p] = 1}
      #nodyna <send-2007> <SD COMPLEX (private methods)>
      Matrix.send :new, rows, @row_count
    end


    def to_ary
      [l, u, p]
    end
    alias_method :to_a, :to_ary


    attr_reader :pivots


    def singular? ()
      @column_count.times do |j|
        if (@lu[j][j] == 0)
          return true
        end
      end
      false
    end


    def det
      if (@row_count != @column_count)
        Matrix.Raise Matrix::ErrDimensionMismatch
      end
      d = @pivot_sign
      @column_count.times do |j|
        d *= @lu[j][j]
      end
      d
    end
    alias_method :determinant, :det


    def solve b
      if (singular?)
        Matrix.Raise Matrix::ErrNotRegular, "Matrix is singular."
      end
      if b.is_a? Matrix
        if (b.row_count != @row_count)
          Matrix.Raise Matrix::ErrDimensionMismatch
        end

        nx = b.column_count
        m = @pivots.map{|row| b.row(row).to_a}

        @column_count.times do |k|
          (k+1).upto(@column_count-1) do |i|
            nx.times do |j|
              m[i][j] -= m[k][j]*@lu[i][k]
            end
          end
        end
        (@column_count-1).downto(0) do |k|
          nx.times do |j|
            m[k][j] = m[k][j].quo(@lu[k][k])
          end
          k.times do |i|
            nx.times do |j|
              m[i][j] -= m[k][j]*@lu[i][k]
            end
          end
        end
        #nodyna <send-2008> <SD COMPLEX (private methods)>
        Matrix.send :new, m, nx
      else # same algorithm, specialized for simpler case of a vector
        b = convert_to_array(b)
        if (b.size != @row_count)
          Matrix.Raise Matrix::ErrDimensionMismatch
        end

        m = b.values_at(*@pivots)

        @column_count.times do |k|
          (k+1).upto(@column_count-1) do |i|
            m[i] -= m[k]*@lu[i][k]
          end
        end
        (@column_count-1).downto(0) do |k|
          m[k] = m[k].quo(@lu[k][k])
          k.times do |i|
            m[i] -= m[k]*@lu[i][k]
          end
        end
        Vector.elements(m, false)
      end
    end

    def initialize a
      raise TypeError, "Expected Matrix but got #{a.class}" unless a.is_a?(Matrix)
      @lu = a.to_a
      @row_count = a.row_count
      @column_count = a.column_count
      @pivots = Array.new(@row_count)
      @row_count.times do |i|
         @pivots[i] = i
      end
      @pivot_sign = 1
      lu_col_j = Array.new(@row_count)


      @column_count.times do |j|


        @row_count.times do |i|
          lu_col_j[i] = @lu[i][j]
        end


        @row_count.times do |i|
          lu_row_i = @lu[i]


          kmax = [i, j].min
          s = 0
          kmax.times do |k|
            s += lu_row_i[k]*lu_col_j[k]
          end

          lu_row_i[j] = lu_col_j[i] -= s
        end


        p = j
        (j+1).upto(@row_count-1) do |i|
          if (lu_col_j[i].abs > lu_col_j[p].abs)
            p = i
          end
        end
        if (p != j)
          @column_count.times do |k|
            t = @lu[p][k]; @lu[p][k] = @lu[j][k]; @lu[j][k] = t
          end
          k = @pivots[p]; @pivots[p] = @pivots[j]; @pivots[j] = k
          @pivot_sign = -@pivot_sign
        end


        if (j < @row_count && @lu[j][j] != 0)
          (j+1).upto(@row_count-1) do |i|
            @lu[i][j] = @lu[i][j].quo(@lu[j][j])
          end
        end
      end
    end
  end
end
