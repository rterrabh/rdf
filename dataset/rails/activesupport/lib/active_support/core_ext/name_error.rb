class NameError
  def missing_name
    if /undefined local variable or method/ !~ message
      $1 if /((::)?([A-Z]\w*)(::[A-Z]\w*)*)$/ =~ message
    end
  end

  def missing_name?(name)
    if name.is_a? Symbol
      last_name = (missing_name || '').split('::').last
      last_name == name.to_s
    else
      missing_name == name.to_s
    end
  end
end
