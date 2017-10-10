require 'active_support/core_ext/module/aliasing'

class Range
  def include_with_range?(value)
    if value.is_a?(::Range)
      operator = exclude_end? && !value.exclude_end? ? :< : :<=
      #nodyna <send-1096> <SD MODERATE (change-prone variables)>
      include_without_range?(value.first) && value.last.send(operator, last)
    else
      include_without_range?(value)
    end
  end

  alias_method_chain :include?, :range
end
