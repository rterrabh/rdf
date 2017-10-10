class Hash
  def transform_values
    return enum_for(:transform_values) unless block_given?
    result = self.class.new
    each do |key, value|
      result[key] = yield(value)
    end
    result
  end

  def transform_values!
    return enum_for(:transform_values!) unless block_given?
    each do |key, value|
      self[key] = yield(value)
    end
  end
end
