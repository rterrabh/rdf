
class RDoc::Markup::Attributes


  attr_reader :special


  def initialize
    @special = 1

    @name_to_bitmap = [
      [:_SPECIAL_, @special],
    ]

    @next_bitmap = @special << 1
  end


  def bitmap_for name
    bitmap = @name_to_bitmap.assoc name

    unless bitmap then
      bitmap = @next_bitmap
      @next_bitmap <<= 1
      @name_to_bitmap << [name, bitmap]
    else
      bitmap = bitmap.last
    end

    bitmap
  end


  def as_string bitmap
    return 'none' if bitmap.zero?
    res = []

    @name_to_bitmap.each do |name, bit|
      res << name if (bitmap & bit) != 0
    end

    res.join ','
  end


  def each_name_of bitmap
    return enum_for __method__, bitmap unless block_given?

    @name_to_bitmap.each do |name, bit|
      next if bit == @special

      yield name.to_s if (bitmap & bit) != 0
    end
  end

end

