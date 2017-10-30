
class ProjectData

  attr_accessor :totalStatements, :totalDynamicStatements, :totalMethods, :totalMethodsUsingDynamic, :loc, :locDynamic, :totalClasses, :totalClassesWithMethodMissing
  attr_accessor :dynamicStatements

  def initialize
    @totalStatements = 0
    @totalDynamicStatements = 0
    @totalMethods = 0
    @totalMethodsUsingDynamic = 0
    @loc = 0
    @locDynamic = 0
    @totalClasses = 0
    @totalClassesWithMethodMissing = 0
    @dynamicStatements = {}
  end


  def perc(x, y)
    if(y != 0)
      return ((x.to_f / y.to_f) * 100).round(2)
    else
      return 0
    end
  end

  def percMethodsUsingDynamic
    return perc(@totalMethodsUsingDynamic, @totalMethods)
  end

  def percDynamicStatements
    return perc(@totalDynamicStatements, @totalStatements)
  end

  def percLocDynamic()
    return perc(@locDynamic, @loc)
  end

  def percClassesWithMethodMissing()
    return perc(@totalClassesWithMethodMissing, @totalClasses)
  end

  def incrementDynamicStatements(dynamicStatement)
    if(!@dynamicStatements.has_key?(dynamicStatement))
      @dynamicStatements[dynamicStatement] = 0
    end
    @dynamicStatements[dynamicStatement] += 1
    @totalDynamicStatements += 1
  end

  def print()
    puts "Total Statements: #{@totalStatements}"
    puts "Total Dynamic Statements: #{@totalDynamicStatements} (#{percDynamicStatements}%)"
    puts "Total Classes/Modules: #{@totalClasses}"
    puts "Total Classes/Modules with method_missing: #{@totalClassesWithMethodMissing} (#{percClassesWithMethodMissing}%)"
    puts "Total Methods: #{@totalMethods}"
    puts "Total Methods Using Dynamic Statements: #{@totalMethodsUsingDynamic} (#{percMethodsUsingDynamic}%)"
    puts "LOC: #{@loc}"
    puts "LOC With Dynamic Statements: #{@locDynamic} (#{percLocDynamic}%)"
    @dynamicStatements.each do |dynamicStatement, occurences|
      puts "#{dynamicStatement}: #{occurences} (#{perc(occurences, @totalDynamicStatements)}%)"
    end
  end
end
