class Range
  def overlaps?(other)
    cover?(other.first) || other.cover?(first)
  end
end
