class Checker


  def self.hasStatement?(statement, line)
    statement = statement.to_sym
    if(statement == :send)
      return hasSend?(line)
    elsif(statement == :instance_exec)
      return hasInstanceExec?(line)
    elsif(statement == :instance_eval)
      return hasInstanceEval?(line)
    elsif(statement == :eval)
      return hasEval?(line)
    elsif(statement == :define_method)
      return hasDefineMethod?(line)
    elsif(statement == :const_get)
      return hasConstGet?(line)
    elsif(statement == :const_set)
      return hasConstSet?(line)
    end
    return false
  end


  private

  def self.allOccurrences(statement, line)
    index = 0
    occurrences = []
    while (!index.nil?)
      index = line.index(statement, index)
      if(!index.nil?)
        occurrences << index
        index += statement.length
      end
    end
    return occurrences
  end


  def self.occurences(statement, line)
    alphabet = "_abcdefghijklmnopqrstuvwxyz"
    totalFound = 0
    allOccurrences(statement, line).each do |index|
      if (index >= 1 && alphabet.index(line[index-1]) != nil)
        next
      elsif (index + statement.length < line.length && alphabet.index(line[index + statement.length]) != nil )
        next
      end
      totalFound += 1
    end
    return totalFound
  end

  def self.hasSend?(line)
    if line.include?("public_send")
      return 1
    end
    return occurences("send", line)
  end

  def self.hasInstanceExec?(line)
    return occurences("instance_exec", line)
  end

  def self.hasInstanceEval?(line)
    return occurences("instance_eval", line)
  end

  def self.hasEval?(line)
    return occurences("eval", line)
  end

  def self.hasDefineMethod?(line)
    return occurences("define_method", line)
  end

  def self.hasConstGet?(line)
    return occurences("const_get", line)
  end

  def self.hasConstSet?(line)
    return occurences("const_set", line)
  end
end
