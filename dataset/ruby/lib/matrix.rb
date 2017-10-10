
require "e2mmap.rb"

module ExceptionForMatrix # :nodoc:
  extend Exception2MessageMapper
  def_e2message(TypeError, "wrong argument type %s (expected %s)")
  def_e2message(ArgumentError, "Wrong # of arguments(%d for %d)")

  def_exception("ErrDimensionMismatch", "\#{self.name} dimension mismatch")
  def_exception("ErrNotRegular", "Not Regular Matrix")
  def_exception("ErrOperationNotDefined", "Operation(%s) can\\'t be defined: %s op %s")
  def_exception("ErrOperationNotImplemented", "Sorry, Operation(%s) not implemented: %s op %s")
end

class Matrix
  include Enumerable
  include ExceptionForMatrix
  autoload :EigenvalueDecomposition, "matrix/eigenvalue_decomposition"
  autoload :LUPDecomposition, "matrix/lup_decomposition"

  private_class_method :new
  attr_reader :rows
  protected :rows

  def Matrix.[](*rows)
    rows(rows, false)
  end

  def Matrix.rows(rows, copy = true)
    rows = convert_to_array(rows, copy)
    rows.map! do |row|
      convert_to_array(row, copy)
    end
    size = (rows[0] || []).size
    rows.each do |row|
      raise ErrDimensionMismatch, "row size differs (#{row.size} should be #{size})" unless row.size == size
    end
    new rows, size
  end

  def Matrix.columns(columns)
    rows(columns, false).transpose
  end

  def Matrix.build(row_count, column_count = row_count)
    row_count = CoercionHelper.coerce_to_int(row_count)
    column_count = CoercionHelper.coerce_to_int(column_count)
    raise ArgumentError if row_count < 0 || column_count < 0
    return to_enum :build, row_count, column_count unless block_given?
    rows = Array.new(row_count) do |i|
      Array.new(column_count) do |j|
        yield i, j
      end
    end
    new rows, column_count
  end

  def Matrix.diagonal(*values)
    size = values.size
    return Matrix.empty if size == 0
    rows = Array.new(size) {|j|
      row = Array.new(size, 0)
      row[j] = values[j]
      row
    }
    new rows
  end

  def Matrix.scalar(n, value)
    diagonal(*Array.new(n, value))
  end

  def Matrix.identity(n)
    scalar(n, 1)
  end
  class << Matrix
    alias unit identity
    alias I identity
  end

  def Matrix.zero(row_count, column_count = row_count)
    rows = Array.new(row_count){Array.new(column_count, 0)}
    new rows, column_count
  end

  def Matrix.row_vector(row)
    row = convert_to_array(row)
    new [row]
  end

  def Matrix.column_vector(column)
    column = convert_to_array(column)
    new [column].transpose, 1
  end

  def Matrix.empty(row_count = 0, column_count = 0)
    raise ArgumentError, "One size must be 0" if column_count != 0 && row_count != 0
    raise ArgumentError, "Negative size" if column_count < 0 || row_count < 0

    new([[]]*row_count, column_count)
  end

  def Matrix.vstack(x, *matrices)
    raise TypeError, "Expected a Matrix, got a #{x.class}" unless x.is_a?(Matrix)
    #nodyna <send-2332> <SD EASY (private methods)>
    result = x.send(:rows).map(&:dup)
    matrices.each do |m|
      raise TypeError, "Expected a Matrix, got a #{m.class}" unless m.is_a?(Matrix)
      if m.column_count != x.column_count
        raise ErrDimensionMismatch, "The given matrices must have #{x.column_count} columns, but one has #{m.column_count}"
      end
      #nodyna <send-2333> <SD EASY (private methods)>
      result.concat(m.send(:rows))
    end
    new result, x.column_count
  end


  def Matrix.hstack(x, *matrices)
    raise TypeError, "Expected a Matrix, got a #{x.class}" unless x.is_a?(Matrix)
    #nodyna <send-2334> <SD EASY (private methods)>
    result = x.send(:rows).map(&:dup)
    total_column_count = x.column_count
    matrices.each do |m|
      raise TypeError, "Expected a Matrix, got a #{m.class}" unless m.is_a?(Matrix)
      if m.row_count != x.row_count
        raise ErrDimensionMismatch, "The given matrices must have #{x.row_count} rows, but one has #{m.row_count}"
      end
      result.each_with_index do |row, i|
        #nodyna <send-2335> <SD EASY (private methods)>
        row.concat m.send(:rows)[i]
      end
      total_column_count += m.column_count
    end
    new result, total_column_count
  end

  def initialize(rows, column_count = rows[0].size)
    @rows = rows
    @column_count = column_count
  end

  def new_matrix(rows, column_count = rows[0].size) # :nodoc:
    #nodyna <send-2336> <SD EASY (private methods)>
    self.class.send(:new, rows, column_count) # bypass privacy of Matrix.new
  end
  private :new_matrix

  def [](i, j)
    @rows.fetch(i){return nil}[j]
  end
  alias element []
  alias component []

  def []=(i, j, v)
    @rows[i][j] = v
  end
  alias set_element []=
  alias set_component []=
  private :[]=, :set_element, :set_component

  def row_count
    @rows.size
  end

  alias_method :row_size, :row_count
  attr_reader :column_count
  alias_method :column_size, :column_count

  def row(i, &block) # :yield: e
    if block_given?
      @rows.fetch(i){return self}.each(&block)
      self
    else
      Vector.elements(@rows.fetch(i){return nil})
    end
  end

  def column(j) # :yield: e
    if block_given?
      return self if j >= column_count || j < -column_count
      row_count.times do |i|
        yield @rows[i][j]
      end
      self
    else
      return nil if j >= column_count || j < -column_count
      col = Array.new(row_count) {|i|
        @rows[i][j]
      }
      Vector.elements(col, false)
    end
  end

  def collect(&block) # :yield: e
    return to_enum(:collect) unless block_given?
    rows = @rows.collect{|row| row.collect(&block)}
    new_matrix rows, column_count
  end
  alias map collect

  def each(which = :all) # :yield: e
    return to_enum :each, which unless block_given?
    last = column_count - 1
    case which
    when :all
      block = Proc.new
      @rows.each do |row|
        row.each(&block)
      end
    when :diagonal
      @rows.each_with_index do |row, row_index|
        yield row.fetch(row_index){return self}
      end
    when :off_diagonal
      @rows.each_with_index do |row, row_index|
        column_count.times do |col_index|
          yield row[col_index] unless row_index == col_index
        end
      end
    when :lower
      @rows.each_with_index do |row, row_index|
        0.upto([row_index, last].min) do |col_index|
          yield row[col_index]
        end
      end
    when :strict_lower
      @rows.each_with_index do |row, row_index|
        [row_index, column_count].min.times do |col_index|
          yield row[col_index]
        end
      end
    when :strict_upper
      @rows.each_with_index do |row, row_index|
        (row_index+1).upto(last) do |col_index|
          yield row[col_index]
        end
      end
    when :upper
      @rows.each_with_index do |row, row_index|
        row_index.upto(last) do |col_index|
          yield row[col_index]
        end
      end
    else
      raise ArgumentError, "expected #{which.inspect} to be one of :all, :diagonal, :off_diagonal, :lower, :strict_lower, :strict_upper or :upper"
    end
    self
  end

  def each_with_index(which = :all) # :yield: e, row, column
    return to_enum :each_with_index, which unless block_given?
    last = column_count - 1
    case which
    when :all
      @rows.each_with_index do |row, row_index|
        row.each_with_index do |e, col_index|
          yield e, row_index, col_index
        end
      end
    when :diagonal
      @rows.each_with_index do |row, row_index|
        yield row.fetch(row_index){return self}, row_index, row_index
      end
    when :off_diagonal
      @rows.each_with_index do |row, row_index|
        column_count.times do |col_index|
          yield row[col_index], row_index, col_index unless row_index == col_index
        end
      end
    when :lower
      @rows.each_with_index do |row, row_index|
        0.upto([row_index, last].min) do |col_index|
          yield row[col_index], row_index, col_index
        end
      end
    when :strict_lower
      @rows.each_with_index do |row, row_index|
        [row_index, column_count].min.times do |col_index|
          yield row[col_index], row_index, col_index
        end
      end
    when :strict_upper
      @rows.each_with_index do |row, row_index|
        (row_index+1).upto(last) do |col_index|
          yield row[col_index], row_index, col_index
        end
      end
    when :upper
      @rows.each_with_index do |row, row_index|
        row_index.upto(last) do |col_index|
          yield row[col_index], row_index, col_index
        end
      end
    else
      raise ArgumentError, "expected #{which.inspect} to be one of :all, :diagonal, :off_diagonal, :lower, :strict_lower, :strict_upper or :upper"
    end
    self
  end

  SELECTORS = {all: true, diagonal: true, off_diagonal: true, lower: true, strict_lower: true, strict_upper: true, upper: true}.freeze
  def index(*args)
    raise ArgumentError, "wrong number of arguments(#{args.size} for 0-2)" if args.size > 2
    which = (args.size == 2 || SELECTORS.include?(args.last)) ? args.pop : :all
    return to_enum :find_index, which, *args unless block_given? || args.size == 1
    if args.size == 1
      value = args.first
      each_with_index(which) do |e, row_index, col_index|
        return row_index, col_index if e == value
      end
    else
      each_with_index(which) do |e, row_index, col_index|
        return row_index, col_index if yield e
      end
    end
    nil
  end
  alias_method :find_index, :index

  def minor(*param)
    case param.size
    when 2
      row_range, col_range = param
      from_row = row_range.first
      from_row += row_count if from_row < 0
      to_row = row_range.end
      to_row += row_count if to_row < 0
      to_row += 1 unless row_range.exclude_end?
      size_row = to_row - from_row

      from_col = col_range.first
      from_col += column_count if from_col < 0
      to_col = col_range.end
      to_col += column_count if to_col < 0
      to_col += 1 unless col_range.exclude_end?
      size_col = to_col - from_col
    when 4
      from_row, size_row, from_col, size_col = param
      return nil if size_row < 0 || size_col < 0
      from_row += row_count if from_row < 0
      from_col += column_count if from_col < 0
    else
      raise ArgumentError, param.inspect
    end

    return nil if from_row > row_count || from_col > column_count || from_row < 0 || from_col < 0
    rows = @rows[from_row, size_row].collect{|row|
      row[from_col, size_col]
    }
    new_matrix rows, [column_count - from_col, size_col].min
  end

  def first_minor(row, column)
    raise RuntimeError, "first_minor of empty matrix is not defined" if empty?

    unless 0 <= row && row < row_count
      raise ArgumentError, "invalid row (#{row.inspect} for 0..#{row_count - 1})"
    end

    unless 0 <= column && column < column_count
      raise ArgumentError, "invalid column (#{column.inspect} for 0..#{column_count - 1})"
    end

    arrays = to_a
    arrays.delete_at(row)
    arrays.each do |array|
      array.delete_at(column)
    end

    new_matrix arrays, column_count - 1
  end

  def cofactor(row, column)
    raise RuntimeError, "cofactor of empty matrix is not defined" if empty?
    Matrix.Raise ErrDimensionMismatch unless square?

    det_of_minor = first_minor(row, column).determinant
    det_of_minor * (-1) ** (row + column)
  end

  def adjugate
    Matrix.Raise ErrDimensionMismatch unless square?
    Matrix.build(row_count, column_count) do |row, column|
      cofactor(column, row)
    end
  end

  def laplace_expansion(row: nil, column: nil)
    num = row || column

    if !num || (row && column)
      raise ArgumentError, "exactly one the row or column arguments must be specified"
    end

    Matrix.Raise ErrDimensionMismatch unless square?
    raise RuntimeError, "laplace_expansion of empty matrix is not defined" if empty?

    unless 0 <= num && num < row_count
      raise ArgumentError, "invalid num (#{num.inspect} for 0..#{row_count - 1})"
    end

    #nodyna <send-2337> <SD EASY (private methods)>
    send(row ? :row : :column, num).map.with_index { |e, k|
      e * cofactor(*(row ? [num, k] : [k,num]))
    }.inject(:+)
  end
  alias_method :cofactor_expansion, :laplace_expansion



  def diagonal?
    Matrix.Raise ErrDimensionMismatch unless square?
    each(:off_diagonal).all?(&:zero?)
  end

  def empty?
    column_count == 0 || row_count == 0
  end

  def hermitian?
    Matrix.Raise ErrDimensionMismatch unless square?
    each_with_index(:upper).all? do |e, row, col|
      e == rows[col][row].conj
    end
  end

  def lower_triangular?
    each(:strict_upper).all?(&:zero?)
  end

  def normal?
    Matrix.Raise ErrDimensionMismatch unless square?
    rows.each_with_index do |row_i, i|
      rows.each_with_index do |row_j, j|
        s = 0
        rows.each_with_index do |row_k, k|
          s += row_i[k] * row_j[k].conj - row_k[i].conj * row_k[j]
        end
        return false unless s == 0
      end
    end
    true
  end

  def orthogonal?
    Matrix.Raise ErrDimensionMismatch unless square?
    rows.each_with_index do |row, i|
      column_count.times do |j|
        s = 0
        row_count.times do |k|
          s += row[k] * rows[k][j]
        end
        return false unless s == (i == j ? 1 : 0)
      end
    end
    true
  end

  def permutation?
    Matrix.Raise ErrDimensionMismatch unless square?
    cols = Array.new(column_count)
    rows.each_with_index do |row, i|
      found = false
      row.each_with_index do |e, j|
        if e == 1
          return false if found || cols[j]
          found = cols[j] = true
        elsif e != 0
          return false
        end
      end
      return false unless found
    end
    true
  end

  def real?
    all?(&:real?)
  end

  def regular?
    not singular?
  end

  def singular?
    determinant == 0
  end

  def square?
    column_count == row_count
  end

  def symmetric?
    Matrix.Raise ErrDimensionMismatch unless square?
    each_with_index(:strict_upper) do |e, row, col|
      return false if e != rows[col][row]
    end
    true
  end

  def unitary?
    Matrix.Raise ErrDimensionMismatch unless square?
    rows.each_with_index do |row, i|
      column_count.times do |j|
        s = 0
        row_count.times do |k|
          s += row[k].conj * rows[k][j]
        end
        return false unless s == (i == j ? 1 : 0)
      end
    end
    true
  end

  def upper_triangular?
    each(:strict_lower).all?(&:zero?)
  end

  def zero?
    all?(&:zero?)
  end


  def ==(other)
    return false unless Matrix === other &&
                        column_count == other.column_count # necessary for empty matrices
    rows == other.rows
  end

  def eql?(other)
    return false unless Matrix === other &&
                        column_count == other.column_count # necessary for empty matrices
    rows.eql? other.rows
  end

  def clone
    new_matrix @rows.map(&:dup), column_count
  end

  def hash
    @rows.hash
  end


  def *(m) # m is matrix or vector or number
    case(m)
    when Numeric
      rows = @rows.collect {|row|
        row.collect {|e| e * m }
      }
      return new_matrix rows, column_count
    when Vector
      m = self.class.column_vector(m)
      r = self * m
      return r.column(0)
    when Matrix
      Matrix.Raise ErrDimensionMismatch if column_count != m.row_count

      rows = Array.new(row_count) {|i|
        Array.new(m.column_count) {|j|
          (0 ... column_count).inject(0) do |vij, k|
            vij + self[i, k] * m[k, j]
          end
        }
      }
      return new_matrix rows, m.column_count
    else
      return apply_through_coercion(m, __method__)
    end
  end

  def +(m)
    case m
    when Numeric
      Matrix.Raise ErrOperationNotDefined, "+", self.class, m.class
    when Vector
      m = self.class.column_vector(m)
    when Matrix
    else
      return apply_through_coercion(m, __method__)
    end

    Matrix.Raise ErrDimensionMismatch unless row_count == m.row_count && column_count == m.column_count

    rows = Array.new(row_count) {|i|
      Array.new(column_count) {|j|
        self[i, j] + m[i, j]
      }
    }
    new_matrix rows, column_count
  end

  def -(m)
    case m
    when Numeric
      Matrix.Raise ErrOperationNotDefined, "-", self.class, m.class
    when Vector
      m = self.class.column_vector(m)
    when Matrix
    else
      return apply_through_coercion(m, __method__)
    end

    Matrix.Raise ErrDimensionMismatch unless row_count == m.row_count && column_count == m.column_count

    rows = Array.new(row_count) {|i|
      Array.new(column_count) {|j|
        self[i, j] - m[i, j]
      }
    }
    new_matrix rows, column_count
  end

  def /(other)
    case other
    when Numeric
      rows = @rows.collect {|row|
        row.collect {|e| e / other }
      }
      return new_matrix rows, column_count
    when Matrix
      return self * other.inverse
    else
      return apply_through_coercion(other, __method__)
    end
  end

  def inverse
    Matrix.Raise ErrDimensionMismatch unless square?
    #nodyna <send-2338> <SD EASY (private methods)>
    self.class.I(row_count).send(:inverse_from, self)
  end
  alias inv inverse

  def inverse_from(src) # :nodoc:
    last = row_count - 1
    a = src.to_a

    0.upto(last) do |k|
      i = k
      akk = a[k][k].abs
      (k+1).upto(last) do |j|
        v = a[j][k].abs
        if v > akk
          i = j
          akk = v
        end
      end
      Matrix.Raise ErrNotRegular if akk == 0
      if i != k
        a[i], a[k] = a[k], a[i]
        @rows[i], @rows[k] = @rows[k], @rows[i]
      end
      akk = a[k][k]

      0.upto(last) do |ii|
        next if ii == k
        q = a[ii][k].quo(akk)
        a[ii][k] = 0

        (k + 1).upto(last) do |j|
          a[ii][j] -= a[k][j] * q
        end
        0.upto(last) do |j|
          @rows[ii][j] -= @rows[k][j] * q
        end
      end

      (k+1).upto(last) do |j|
        a[k][j] = a[k][j].quo(akk)
      end
      0.upto(last) do |j|
        @rows[k][j] = @rows[k][j].quo(akk)
      end
    end
    self
  end
  private :inverse_from

  def ** (other)
    case other
    when Integer
      x = self
      if other <= 0
        x = self.inverse
        return self.class.identity(self.column_count) if other == 0
        other = -other
      end
      z = nil
      loop do
        z = z ? z * x : x if other[0] == 1
        return z if (other >>= 1).zero?
        x *= x
      end
    when Numeric
      v, d, v_inv = eigensystem
      v * self.class.diagonal(*d.each(:diagonal).map{|e| e ** other}) * v_inv
    else
      Matrix.Raise ErrOperationNotDefined, "**", self.class, other.class
    end
  end

  def +@
    self
  end

  def -@
    collect {|e| -e }
  end


  def determinant
    Matrix.Raise ErrDimensionMismatch unless square?
    m = @rows
    case row_count
    when 0
      +1
    when 1
      + m[0][0]
    when 2
      + m[0][0] * m[1][1] - m[0][1] * m[1][0]
    when 3
      m0, m1, m2 = m
      + m0[0] * m1[1] * m2[2] - m0[0] * m1[2] * m2[1] \
      - m0[1] * m1[0] * m2[2] + m0[1] * m1[2] * m2[0] \
      + m0[2] * m1[0] * m2[1] - m0[2] * m1[1] * m2[0]
    when 4
      m0, m1, m2, m3 = m
      + m0[0] * m1[1] * m2[2] * m3[3] - m0[0] * m1[1] * m2[3] * m3[2] \
      - m0[0] * m1[2] * m2[1] * m3[3] + m0[0] * m1[2] * m2[3] * m3[1] \
      + m0[0] * m1[3] * m2[1] * m3[2] - m0[0] * m1[3] * m2[2] * m3[1] \
      - m0[1] * m1[0] * m2[2] * m3[3] + m0[1] * m1[0] * m2[3] * m3[2] \
      + m0[1] * m1[2] * m2[0] * m3[3] - m0[1] * m1[2] * m2[3] * m3[0] \
      - m0[1] * m1[3] * m2[0] * m3[2] + m0[1] * m1[3] * m2[2] * m3[0] \
      + m0[2] * m1[0] * m2[1] * m3[3] - m0[2] * m1[0] * m2[3] * m3[1] \
      - m0[2] * m1[1] * m2[0] * m3[3] + m0[2] * m1[1] * m2[3] * m3[0] \
      + m0[2] * m1[3] * m2[0] * m3[1] - m0[2] * m1[3] * m2[1] * m3[0] \
      - m0[3] * m1[0] * m2[1] * m3[2] + m0[3] * m1[0] * m2[2] * m3[1] \
      + m0[3] * m1[1] * m2[0] * m3[2] - m0[3] * m1[1] * m2[2] * m3[0] \
      - m0[3] * m1[2] * m2[0] * m3[1] + m0[3] * m1[2] * m2[1] * m3[0]
    else
      determinant_bareiss
    end
  end
  alias_method :det, :determinant

  def determinant_bareiss
    size = row_count
    last = size - 1
    a = to_a
    no_pivot = Proc.new{ return 0 }
    sign = +1
    pivot = 1
    size.times do |k|
      previous_pivot = pivot
      if (pivot = a[k][k]) == 0
        switch = (k+1 ... size).find(no_pivot) {|row|
          a[row][k] != 0
        }
        a[switch], a[k] = a[k], a[switch]
        pivot = a[k][k]
        sign = -sign
      end
      (k+1).upto(last) do |i|
        ai = a[i]
        (k+1).upto(last) do |j|
          ai[j] =  (pivot * ai[j] - ai[k] * a[k][j]) / previous_pivot
        end
      end
    end
    sign * pivot
  end
  private :determinant_bareiss

  def determinant_e
    warn "#{caller(1)[0]}: warning: Matrix#determinant_e is deprecated; use #determinant"
    determinant
  end
  alias det_e determinant_e

  def hstack(*matrices)
    self.class.hstack(self, *matrices)
  end

  def rank
    a = to_a
    last_column = column_count - 1
    last_row = row_count - 1
    pivot_row = 0
    previous_pivot = 1
    0.upto(last_column) do |k|
      switch_row = (pivot_row .. last_row).find {|row|
        a[row][k] != 0
      }
      if switch_row
        a[switch_row], a[pivot_row] = a[pivot_row], a[switch_row] unless pivot_row == switch_row
        pivot = a[pivot_row][k]
        (pivot_row+1).upto(last_row) do |i|
           ai = a[i]
           (k+1).upto(last_column) do |j|
             ai[j] =  (pivot * ai[j] - ai[k] * a[pivot_row][j]) / previous_pivot
           end
         end
        pivot_row += 1
        previous_pivot = pivot
      end
    end
    pivot_row
  end

  def rank_e
    warn "#{caller(1)[0]}: warning: Matrix#rank_e is deprecated; use #rank"
    rank
  end

  def round(ndigits=0)
    map{|e| e.round(ndigits)}
  end

  def trace
    Matrix.Raise ErrDimensionMismatch unless square?
    (0...column_count).inject(0) do |tr, i|
      tr + @rows[i][i]
    end
  end
  alias tr trace

  def transpose
    return self.class.empty(column_count, 0) if row_count.zero?
    new_matrix @rows.transpose, row_count
  end
  alias t transpose

  def vstack(*matrices)
    self.class.vstack(self, *matrices)
  end


  def eigensystem
    EigenvalueDecomposition.new(self)
  end
  alias eigen eigensystem

  def lup
    LUPDecomposition.new(self)
  end
  alias lup_decomposition lup


  def conjugate
    collect(&:conjugate)
  end
  alias conj conjugate

  def imaginary
    collect(&:imaginary)
  end
  alias imag imaginary

  def real
    collect(&:real)
  end

  def rect
    [real, imag]
  end
  alias rectangular rect


  def coerce(other)
    case other
    when Numeric
      return Scalar.new(other), self
    else
      raise TypeError, "#{self.class} can't be coerced into #{other.class}"
    end
  end

  def row_vectors
    Array.new(row_count) {|i|
      row(i)
    }
  end

  def column_vectors
    Array.new(column_count) {|i|
      column(i)
    }
  end

  def to_a
    @rows.collect(&:dup)
  end

  def elements_to_f
    warn "#{caller(1)[0]}: warning: Matrix#elements_to_f is deprecated, use map(&:to_f)"
    map(&:to_f)
  end

  def elements_to_i
    warn "#{caller(1)[0]}: warning: Matrix#elements_to_i is deprecated, use map(&:to_i)"
    map(&:to_i)
  end

  def elements_to_r
    warn "#{caller(1)[0]}: warning: Matrix#elements_to_r is deprecated, use map(&:to_r)"
    map(&:to_r)
  end


  def to_s
    if empty?
      "#{self.class}.empty(#{row_count}, #{column_count})"
    else
      "#{self.class}[" + @rows.collect{|row|
        "[" + row.collect{|e| e.to_s}.join(", ") + "]"
      }.join(", ")+"]"
    end
  end

  def inspect
    if empty?
      "#{self.class}.empty(#{row_count}, #{column_count})"
    else
      "#{self.class}#{@rows.inspect}"
    end
  end


  module ConversionHelper # :nodoc:
    def convert_to_array(obj, copy = false) # :nodoc:
      case obj
      when Array
        copy ? obj.dup : obj
      when Vector
        obj.to_a
      else
        begin
          converted = obj.to_ary
        rescue Exception => e
          raise TypeError, "can't convert #{obj.class} into an Array (#{e.message})"
        end
        raise TypeError, "#{obj.class}#to_ary should return an Array" unless converted.is_a? Array
        converted
      end
    end
    private :convert_to_array
  end

  extend ConversionHelper

  module CoercionHelper # :nodoc:
    def apply_through_coercion(obj, oper)
      coercion = obj.coerce(self)
      raise TypeError unless coercion.is_a?(Array) && coercion.length == 2
      #nodyna <send-2339> <SD COMPLEX (change-prone variables)>
      coercion[0].public_send(oper, coercion[1])
    rescue
      raise TypeError, "#{obj.inspect} can't be coerced into #{self.class}"
    end
    private :apply_through_coercion

    def self.coerce_to(obj, cls, meth) # :nodoc:
      return obj if obj.kind_of?(cls)

      begin
        ret = obj.__send__(meth)
      rescue Exception => e
        raise TypeError, "Coercion error: #{obj.inspect}.#{meth} => #{cls} failed:\n" \
                         "(#{e.message})"
      end
      raise TypeError, "Coercion error: obj.#{meth} did NOT return a #{cls} (was #{ret.class})" unless ret.kind_of? cls
      ret
    end

    def self.coerce_to_int(obj)
      coerce_to(obj, Integer, :to_int)
    end
  end

  include CoercionHelper


  class Scalar < Numeric # :nodoc:
    include ExceptionForMatrix
    include CoercionHelper

    def initialize(value)
      @value = value
    end

    def +(other)
      case other
      when Numeric
        Scalar.new(@value + other)
      when Vector, Matrix
        Scalar.Raise ErrOperationNotDefined, "+", @value.class, other.class
      else
        apply_through_coercion(other, __method__)
      end
    end

    def -(other)
      case other
      when Numeric
        Scalar.new(@value - other)
      when Vector, Matrix
        Scalar.Raise ErrOperationNotDefined, "-", @value.class, other.class
      else
        apply_through_coercion(other, __method__)
      end
    end

    def *(other)
      case other
      when Numeric
        Scalar.new(@value * other)
      when Vector, Matrix
        other.collect{|e| @value * e}
      else
        apply_through_coercion(other, __method__)
      end
    end

    def / (other)
      case other
      when Numeric
        Scalar.new(@value / other)
      when Vector
        Scalar.Raise ErrOperationNotDefined, "/", @value.class, other.class
      when Matrix
        self * other.inverse
      else
        apply_through_coercion(other, __method__)
      end
    end

    def ** (other)
      case other
      when Numeric
        Scalar.new(@value ** other)
      when Vector
        Scalar.Raise ErrOperationNotDefined, "**", @value.class, other.class
      when Matrix
        Scalar.Raise ErrOperationNotImplemented, "**", @value.class, other.class
      else
        apply_through_coercion(other, __method__)
      end
    end
  end

end


class Vector
  include ExceptionForMatrix
  include Enumerable
  include Matrix::CoercionHelper
  extend Matrix::ConversionHelper

  private_class_method :new
  attr_reader :elements
  protected :elements

  def Vector.[](*array)
    new convert_to_array(array, false)
  end

  def Vector.elements(array, copy = true)
    new convert_to_array(array, copy)
  end

  def Vector.basis(size:, index:)
    raise ArgumentError, "invalid size (#{size} for 1..)" if size < 1
    raise ArgumentError, "invalid index (#{index} for 0...#{size})" unless 0 <= index && index < size
    array = Array.new(size, 0)
    array[index] = 1
    new convert_to_array(array, false)
  end

  def initialize(array)
    @elements = array
  end


  def [](i)
    @elements[i]
  end
  alias element []
  alias component []

  def []=(i, v)
    @elements[i]= v
  end
  alias set_element []=
  alias set_component []=
  private :[]=, :set_element, :set_component

  def size
    @elements.size
  end


  def each(&block)
    return to_enum(:each) unless block_given?
    @elements.each(&block)
    self
  end

  def each2(v) # :yield: e1, e2
    raise TypeError, "Integer is not like Vector" if v.kind_of?(Integer)
    Vector.Raise ErrDimensionMismatch if size != v.size
    return to_enum(:each2, v) unless block_given?
    size.times do |i|
      yield @elements[i], v[i]
    end
    self
  end

  def collect2(v) # :yield: e1, e2
    raise TypeError, "Integer is not like Vector" if v.kind_of?(Integer)
    Vector.Raise ErrDimensionMismatch if size != v.size
    return to_enum(:collect2, v) unless block_given?
    Array.new(size) do |i|
      yield @elements[i], v[i]
    end
  end


  def Vector.independent?(*vs)
    vs.each do |v|
      raise TypeError, "expected Vector, got #{v.class}" unless v.is_a?(Vector)
      Vector.Raise ErrDimensionMismatch unless v.size == vs.first.size
    end
    return false if vs.count > vs.first.size
    Matrix[*vs].rank.eql?(vs.count)
  end

  def independent?(*vs)
    self.class.independent?(self, *vs)
  end


  def ==(other)
    return false unless Vector === other
    @elements == other.elements
  end

  def eql?(other)
    return false unless Vector === other
    @elements.eql? other.elements
  end

  def clone
    self.class.elements(@elements)
  end

  def hash
    @elements.hash
  end


  def *(x)
    case x
    when Numeric
      els = @elements.collect{|e| e * x}
      self.class.elements(els, false)
    when Matrix
      Matrix.column_vector(self) * x
    when Vector
      Vector.Raise ErrOperationNotDefined, "*", self.class, x.class
    else
      apply_through_coercion(x, __method__)
    end
  end

  def +(v)
    case v
    when Vector
      Vector.Raise ErrDimensionMismatch if size != v.size
      els = collect2(v) {|v1, v2|
        v1 + v2
      }
      self.class.elements(els, false)
    when Matrix
      Matrix.column_vector(self) + v
    else
      apply_through_coercion(v, __method__)
    end
  end

  def -(v)
    case v
    when Vector
      Vector.Raise ErrDimensionMismatch if size != v.size
      els = collect2(v) {|v1, v2|
        v1 - v2
      }
      self.class.elements(els, false)
    when Matrix
      Matrix.column_vector(self) - v
    else
      apply_through_coercion(v, __method__)
    end
  end

  def /(x)
    case x
    when Numeric
      els = @elements.collect{|e| e / x}
      self.class.elements(els, false)
    when Matrix, Vector
      Vector.Raise ErrOperationNotDefined, "/", self.class, x.class
    else
      apply_through_coercion(x, __method__)
    end
  end

  def +@
    self
  end

  def -@
    collect {|e| -e }
  end


  def inner_product(v)
    Vector.Raise ErrDimensionMismatch if size != v.size

    p = 0
    each2(v) {|v1, v2|
      p += v1 * v2.conj
    }
    p
  end
  alias_method :dot, :inner_product

  def cross_product(*vs)
    raise ErrOperationNotDefined, "cross product is not defined on vectors of dimension #{size}" unless size >= 2
    raise ArgumentError, "wrong number of arguments (#{vs.size} for #{size - 2})" unless vs.size == size - 2
    vs.each do |v|
      raise TypeError, "expected Vector, got #{v.class}" unless v.is_a? Vector
      Vector.Raise ErrDimensionMismatch unless v.size == size
    end
    case size
    when 2
      Vector[-@elements[1], @elements[0]]
    when 3
      v = vs[0]
      Vector[ v[2]*@elements[1] - v[1]*@elements[2],
        v[0]*@elements[2] - v[2]*@elements[0],
        v[1]*@elements[0] - v[0]*@elements[1] ]
    else
      rows = self, *vs, Array.new(size) {|i| Vector.basis(size: size, index: i) }
      Matrix.rows(rows).laplace_expansion(row: size - 1)
    end
  end
  alias_method :cross, :cross_product

  def collect(&block) # :yield: e
    return to_enum(:collect) unless block_given?
    els = @elements.collect(&block)
    self.class.elements(els, false)
  end
  alias map collect

  def magnitude
    Math.sqrt(@elements.inject(0) {|v, e| v + e.abs2})
  end
  alias r magnitude
  alias norm magnitude

  def map2(v, &block) # :yield: e1, e2
    return to_enum(:map2, v) unless block_given?
    els = collect2(v, &block)
    self.class.elements(els, false)
  end

  class ZeroVectorError < StandardError
  end
  def normalize
    n = magnitude
    raise ZeroVectorError, "Zero vectors can not be normalized" if n == 0
    self / n
  end

  def angle_with(v)
    raise TypeError, "Expected a Vector, got a #{v.class}" unless v.is_a?(Vector)
    Vector.Raise ErrDimensionMismatch if size != v.size
    prod = magnitude * v.magnitude
    raise ZeroVectorError, "Can't get angle of zero vector" if prod == 0

    Math.acos( inner_product(v) / prod )
  end


  def covector
    Matrix.row_vector(self)
  end

  def to_a
    @elements.dup
  end

  def elements_to_f
    warn "#{caller(1)[0]}: warning: Vector#elements_to_f is deprecated"
    map(&:to_f)
  end

  def elements_to_i
    warn "#{caller(1)[0]}: warning: Vector#elements_to_i is deprecated"
    map(&:to_i)
  end

  def elements_to_r
    warn "#{caller(1)[0]}: warning: Vector#elements_to_r is deprecated"
    map(&:to_r)
  end

  def coerce(other)
    case other
    when Numeric
      return Matrix::Scalar.new(other), self
    else
      raise TypeError, "#{self.class} can't be coerced into #{other.class}"
    end
  end


  def to_s
    "Vector[" + @elements.join(", ") + "]"
  end

  def inspect
    "Vector" + @elements.inspect
  end
end
