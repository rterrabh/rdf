class Checker


  DYNAMIC_FEATURES = [:class_eval, :class_variable_get, :class_variable_set, :const_set, :const_get, 
                      :define_method, :eval, :instance_eval, :instance_exec, :instance_variable_get,
                      :instance_variable_set, :instance_exec, :module_eval, :send
                     ]

  def self.createDynamicCounter()
    counter = {}
    DYNAMIC_FEATURES.each do |dynamicFeature|
      counter[dynamicFeature] = 0
    end
    return counter
  end

  def self.getOccurences(line)
    counter = createDynamicCounter()
    DYNAMIC_FEATURES.each do |dynamicFeature|
      if(self.respond_to?("#{dynamicFeature}_occurences"))
        counter[dynamicFeature] = self.send("#{dynamicFeature}_occurences", line)
      else
        counter[dynamicFeature] = self.getDefaultOccurences(dynamicFeature, line)
      end
    end
    return counter
  end

  def self.getDefaultOccurences(dynamicFeature, line)
    alphabet = "_abcdefghijklmnopqrstuvwxyz"
    offset = 0
    occurences = 0
    index = 0
    while(!index.nil?)
      index = line.index(dynamicFeature.to_s, offset)
      if(!index.nil?)
        if(index + dynamicFeature.length == line.length)
          occurences += 1
        elsif(index + dynamicFeature.length < line.length && !alphabet.include?(line[index + dynamicFeature.length]) &&
               (index == 0 || !alphabet.include?(line[index-1])))
          occurences += 1
        end
        offset = index + dynamicFeature.length
      end
    end
    return occurences
  end

  def self.send_occurences(line)
    if line.include?("public_send")
      return 1
    end
    return getDefaultOccurences(:send, line)
  end
end
