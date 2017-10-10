class Range
  RANGE_FORMATS = {
    :db => Proc.new { |start, stop| "BETWEEN '#{start.to_s(:db)}' AND '#{stop.to_s(:db)}'" }
  }

  def to_formatted_s(format = :default)
    if formatter = RANGE_FORMATS[format]
      formatter.call(first, last)
    else
      to_default_s
    end
  end

  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s
end
