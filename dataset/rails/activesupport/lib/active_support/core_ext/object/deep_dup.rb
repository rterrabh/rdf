require 'active_support/core_ext/object/duplicable'

class Object
  def deep_dup
    duplicable? ? dup : self
  end
end

class Array
  def deep_dup
    map { |it| it.deep_dup }
  end
end

class Hash
  def deep_dup
    each_with_object(dup) do |(key, value), hash|
      hash[key.deep_dup] = value.deep_dup
    end
  end
end
