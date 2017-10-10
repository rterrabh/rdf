class Array
  def in_groups_of(number, fill_with = nil)
    if number.to_i <= 0
      raise ArgumentError,
        "Group size must be a positive integer, was #{number.inspect}"
    end

    if fill_with == false
      collection = self
    else
      padding = (number - size % number) % number
      collection = dup.concat(Array.new(padding, fill_with))
    end

    if block_given?
      collection.each_slice(number) { |slice| yield(slice) }
    else
      collection.each_slice(number).to_a
    end
  end

  def in_groups(number, fill_with = nil)
    division = size.div number
    modulo = size % number

    groups = []
    start = 0

    number.times do |index|
      length = division + (modulo > 0 && modulo > index ? 1 : 0)
      groups << last_group = slice(start, length)
      last_group << fill_with if fill_with != false &&
        modulo > 0 && length == division
      start += length
    end

    if block_given?
      groups.each { |g| yield(g) }
    else
      groups
    end
  end

  def split(value = nil)
    if block_given?
      inject([[]]) do |results, element|
        if yield(element)
          results << []
        else
          results.last << element
        end

        results
      end
    else
      results, arr = [[]], self.dup
      until arr.empty?
        if (idx = arr.index(value))
          results.last.concat(arr.shift(idx))
          arr.shift
          results << []
        else
          results.last.concat(arr.shift(arr.size))
        end
      end
      results
    end
  end
end
