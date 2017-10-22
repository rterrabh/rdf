
class ProjectData

  attr_accessor :totalStatements, :totalDynamicStatements, :totalMethods, :totalMethodsUsingDynamic, :loc, :locDynamic, :totalClasses, :totalClassesWithMethodMissing
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

  def percMethodsUsingDynamic
    if(@totalMethods != 0)
      return ((@totalMethodsUsingDynamic.to_f / @totalMethods.to_f) * 100).round(2)
    else
      return 0
    end
  end

  def percDynamicStatements
    if(@totalStatements != 0)
      return ((@totalDynamicStatements.to_f / @totalStatements.to_f) * 100).round(2)
    else
      return 0
    end
  end

  def percLocDynamic()
    if(@loc != 0)
      return ((@locDynamic.to_f / @loc.to_f) * 100).round(2)
    else
      return 0
    end
  end

  def percClassesWithMethodMissing()
    if(@totalClasses != 0)
      return ((@totalClassesWithMethodMissing.to_f / @totalClasses.to_f) * 100).round(2)
    else
      0
    end
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
  end
end
