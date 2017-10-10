class Array
  def from(position)
    self[position, length] || []
  end

  def to(position)
    if position >= 0
      first position + 1
    else
      self[0..position]
    end
  end

  def second
    self[1]
  end

  def third
    self[2]
  end

  def fourth
    self[3]
  end

  def fifth
    self[4]
  end

  def forty_two
    self[41]
  end
end
