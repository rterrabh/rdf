require 'active_support/inflector'

class Integer
  def ordinalize
    ActiveSupport::Inflector.ordinalize(self)
  end

  def ordinal
    ActiveSupport::Inflector.ordinal(self)
  end
end
