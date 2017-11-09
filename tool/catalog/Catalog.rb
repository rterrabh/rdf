require_relative 'Item'
class Catalog

  attr_reader :items
  attr_writer :totalFiles

  def initialize()
    @items = {}
    @totalFiles = 0
  end

  def addItem(item)
    @items[item] = Item.new(item)
  end

  def increaseClassification(item, classification)
    if !@items.has_key?(item)
      addItem(item)
    end
    @items[item].increaseClassification(classification)
  end

  def showCatalog
    classifications = {}
    allClassifications = 0
    @items.sort.each do |key, item|
      puts "#{createTitle(key)}"
      total = 0
      item.classifications.sort.each do |classification, times|
        puts "  #{classification}: #{times}"
        total += times
      end
      allClassifications += total
      puts "  Total: #{total}"
    end
    puts "=" * 80
    puts "Total: #{allClassifications}"
  end

  def createTitle(name)
    totalCaracters = 78 - name.size
    caracters = "=" * (totalCaracters/2)
    if(totalCaracters % 2 == 0)
      return "#{caracters} #{name} #{caracters}"
    else
      return "#{caracters} #{name} #{caracters}="
    end
  end

  private :createTitle
end
