class String
  def exclude?(string)
    !include?(string)
  end
end
