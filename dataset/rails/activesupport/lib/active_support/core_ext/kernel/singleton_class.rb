module Kernel
  #nodyna <class_eval-1102> <not yet classified>
  def class_eval(*args, &block)
    #nodyna <class_eval-1103> <not yet classified>
    singleton_class.class_eval(*args, &block)
  end
end
