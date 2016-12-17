class Item
  attr_reader :name
  attr_reader :classifications

  def initialize(nome)
    @name = nome
    @classifications = {}
    @classifications["not yet classified"] = 0
  end

  def add_classification(name)
    if !@classifications.has_key?(name)
      @classifications[name] = 0
    end
  end

  def increase_classification(name)
    if !@classifications.has_key?(name)
      add_classification(name)
    end
    @classifications[name] += 1
  end

  def get_ocorrencias(name)
    if !@classifications.has_key?(name)
      return 0
    else
      return @classifications[name]
    end
  end

end