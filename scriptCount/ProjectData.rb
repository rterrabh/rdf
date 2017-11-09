
class ProjectData

  attr_accessor :totalStatements, :totalDynamicStatements, :totalMethods, :totalMethodsUsingDynamic, :loc, :locDynamic, :totalClasses, :totalClassesWithMethodMissing
  attr_accessor :dynamicStatements, :rbfiles

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
    @rbfiles = 0
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
    puts "Ruby Files: #{@rbfiles}"
    puts "Statements: #{@totalDynamicStatements} / #{@totalStatements} (#{percDynamicStatements}%)"
    puts "Method Missing: #{@totalClassesWithMethodMissing} / #{@totalClasses} (#{percClassesWithMethodMissing}%)"
    puts "Methods: #{@totalMethodsUsingDynamic} / #{@totalMethods} (#{percMethodsUsingDynamic}%)"
    puts "LOC: #{@locDynamic} / #{@loc} (#{percLocDynamic}%)"
    @dynamicStatements.sort.each do |dynamicStatement, occurences|
      puts "#{dynamicStatement}: #{occurences} (#{perc(occurences, @totalDynamicStatements)}%)"
    end
  end

  def tex(projectName)
    string = ""
    @dynamicStatements.sort.each do |dynamicStatement, occurences|
      string = "#{string} & #{occurences}"
    end
    puts "#{projectName} #{string}"
    puts "\\\\[0.001cm]"
  end
end
