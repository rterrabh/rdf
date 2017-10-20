module Kernel
  #nodyna <class_eval-1102> <CE COMPLEX (block execution)>
  def class_eval(*args, &block)
    #nodyna <class_eval-1103> <CE COMPLEX (block execution)>
    singleton_class.class_eval(*args, &block)
  end
end
