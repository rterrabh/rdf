class Object
  def try(*a, &b)
    try!(*a, &b) if a.empty? || respond_to?(a.first)
  end

  
  def try!(*a, &b)
    if a.empty? && block_given?
      if b.arity.zero?
        #nodyna <instance_eval-1093> <IEV COMPLEX (block execution)>
        instance_eval(&b)
      else
        yield self
      end
    else
      #nodyna <send-1094> <SD COMPLEX (change-prone variables)>
      public_send(*a, &b)
    end
  end
end

class NilClass
  def try(*args)
    nil
  end

  def try!(*args)
    nil
  end
end
