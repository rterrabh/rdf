class Item
  attr_reader :name
  attr_reader :classifications

  def initialize(name)
    @name = name
    @classifications = {}
    @classifications["not yet classified"] = 0
  end

  def addClassification(classification)
    @classifications[classification] = 0
  end

  def increaseClassification(classification)
    if !@classifications.has_key?(classification)
      addClassification(classification)
    end
    @classifications[classification] += 1
  end

  def getNumberOfOccurrences(classification)
    if !@classifications.has_key?(classification)
      return 0
    else
      return @classifications[classification]
    end
  end

end
