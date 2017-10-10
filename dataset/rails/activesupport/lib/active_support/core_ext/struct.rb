class Struct # :nodoc:
  def to_h
    Hash[members.zip(values)]
  end
end unless Struct.instance_methods.include?(:to_h)
