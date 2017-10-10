class Object
  def in?(another_object)
    another_object.include?(self)
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #in? must respond to #include?")
  end

  def presence_in(another_object)
    self.in?(another_object) ? self : nil
  end
end
