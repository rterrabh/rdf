class Object
  def duplicable?
    true
  end
end

class NilClass
  def duplicable?
    false
  end
end

class FalseClass
  def duplicable?
    false
  end
end

class TrueClass
  def duplicable?
    false
  end
end

class Symbol
  def duplicable?
    false
  end
end

class Numeric
  def duplicable?
    false
  end
end

require 'bigdecimal'
class BigDecimal
  begin
    BigDecimal.new('4.56').dup

    def duplicable?
      true
    end
  rescue TypeError
  end
end

class Method
  def duplicable?
    false
  end
end
