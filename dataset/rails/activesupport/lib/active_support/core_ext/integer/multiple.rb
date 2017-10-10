class Integer
  def multiple_of?(number)
    number != 0 ? self % number == 0 : zero?
  end
end
