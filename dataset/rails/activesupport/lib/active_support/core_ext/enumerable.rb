module Enumerable
  def sum(identity = 0, &block)
    if block_given?
      map(&block).sum(identity)
    else
      inject { |sum, element| sum + element } || identity
    end
  end

  def index_by
    if block_given?
      Hash[map { |elem| [yield(elem), elem] }]
    else
      to_enum(:index_by) { size if respond_to?(:size) }
    end
  end

  def many?
    cnt = 0
    if block_given?
      any? do |element|
        cnt += 1 if yield element
        cnt > 1
      end
    else
      any? { (cnt += 1) > 1 }
    end
  end

  def exclude?(object)
    !include?(object)
  end
end

class Range #:nodoc:
  def sum(identity = 0)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      actual_last = exclude_end? ? (last - 1) : last
      if actual_last >= first
        (actual_last - first + 1) * (actual_last + first) / 2
      else
        identity
      end
    end
  end
end
