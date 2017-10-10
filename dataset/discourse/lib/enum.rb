class Enum < Hash
  def initialize(*members)
    super({})

    options = members.extract_options!
    start = options.fetch(:start) { 1 }

    update Hash[members.zip(start..members.count + start)]
  end

  def [](id_or_value)
    fetch(id_or_value) { key(id_or_value) }
  end

  def valid?(member)
    has_key?(member)
  end

  def only(*keys)
    dup.tap do |d|
      d.keep_if { |k| keys.include?(k) }
    end
  end

  def except(*keys)
    dup.tap do |d|
      d.delete_if { |k| keys.include?(k) }
    end
  end
end
