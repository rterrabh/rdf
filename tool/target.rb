  def call_class_eval()
    #nodyna <ID:class_eval-1> <not yet classified>
    class_eval(:foo)
    #nodyna <ID:class_eval-2> <not yet classified>
    #nodyna <ID:class_eval-3> <not yet classified>
    class_eval(:foo).class_eval(:foo)
    #nodyna <ID:class_eval-4> <deixa aqui!>
    class_eval(:foo)_not
    not_class_eval(:foo)
    not_class_eval(:foo)_not
  end

  def call_class_variable_get()
    #nodyna <ID:class_variable_get-5> <not yet classified>
    class_variable_get(:foo)
    #nodyna <ID:class_variable_get-6> <not yet classified>
    #nodyna <ID:class_variable_get-7> <deixa aqui!>
    class_variable_get(:foo).class_variable_get(:foo)
    #nodyna <ID:class_variable_get-8> <not yet classified>
    class_variable_get(:foo)_not
    not_class_variable_get(:foo)
    not_class_variable_get(:foo)_not
  end

  def call_class_variable_set()
    #nodyna <ID:class_variable_set-9> <not yet classified>
    class_variable_set(:foo)
    #nodyna <ID:class_variable_set-10> <not yet classified>
    #nodyna <ID:class_variable_set-11> <not yet classified>
    class_variable_set(:foo).class_variable_set(:foo)
    #nodyna <ID:class_variable_set-12> <not yet classified>
    class_variable_set(:foo)_not
    not_class_variable_set(:foo)
    not_class_variable_set(:foo)_not
  end

  def call_const_set()
    #nodyna <ID:const_set-13> <not yet classified>
    const_set(:foo)
    #nodyna <ID:const_set-14> <not yet classified>
    #nodyna <ID:const_set-15> <not yet classified>
    const_set(:foo).const_set(:foo)
    #nodyna <ID:const_set-16> <not yet classified>
    const_set(:foo)_not
    not_const_set(:foo)
    not_const_set(:foo)_not
  end

  def call_const_get()
    #nodyna <ID:const_get-17> <not yet classified>
    const_get(:foo)
    #nodyna <ID:const_get-18> <not yet classified>
    #nodyna <ID:const_get-19> <not yet classified>
    const_get(:foo).const_get(:foo)
    #nodyna <ID:const_get-20> <not yet classified>
    const_get(:foo)_not
    not_const_get(:foo)
    not_const_get(:foo)_not
  end

  def call_define_method()
    #nodyna <ID:define_method-21> <not yet classified>
    define_method(:foo)
    #nodyna <ID:define_method-22> <not yet classified>
    #nodyna <ID:define_method-23> <not yet classified>
    define_method(:foo).define_method(:foo)
    #nodyna <ID:define_method-24> <not yet classified>
    define_method(:foo)_not
    not_define_method(:foo)
    not_define_method(:foo)_not
  end

  def call_eval()
    #nodyna <ID:eval-25> <not yet classified>
    eval(:foo)
    #nodyna <ID:eval-26> <not yet classified>
    #nodyna <ID:eval-27> <not yet classified>
    eval(:foo).eval(:foo)
    #nodyna <ID:eval-28> <not yet classified>
    eval(:foo)_not
    not_eval(:foo)
    not_eval(:foo)_not
  end

  def call_instance_eval()
    #nodyna <ID:instance_eval-29> <not yet classified>
    instance_eval(:foo)
    #nodyna <ID:instance_eval-30> <not yet classified>
    #nodyna <ID:instance_eval-31> <not yet classified>
    instance_eval(:foo).instance_eval(:foo)
    #nodyna <ID:instance_eval-32> <not yet classified>
    instance_eval(:foo)_not
    not_instance_eval(:foo)
    not_instance_eval(:foo)_not
  end

  def call_instance_exec()
    #nodyna <ID:instance_exec-33> <not yet classified>
    instance_exec(:foo)
    #nodyna <ID:instance_exec-34> <not yet classified>
    #nodyna <ID:instance_exec-35> <not yet classified>
    instance_exec(:foo).instance_exec(:foo)
    #nodyna <ID:instance_exec-36> <not yet classified>
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_instance_variable_get()
    #nodyna <ID:instance_variable_get-37> <not yet classified>
    instance_variable_get(:foo)
    #nodyna <ID:instance_variable_get-38> <not yet classified>
    #nodyna <ID:instance_variable_get-39> <not yet classified>
    instance_variable_get(:foo).instance_variable_get(:foo)
    #nodyna <ID:instance_variable_get-40> <not yet classified>
    instance_variable_get(:foo)_not
    not_instance_variable_get(:foo)
    not_instance_variable_get(:foo)_not
  end

  def call_instance_variable_set()
    #nodyna <ID:instance_variable_set-41> <not yet classified>
    instance_variable_set(:foo)
    #nodyna <ID:instance_variable_set-42> <not yet classified>
    #nodyna <ID:instance_variable_set-43> <not yet classified>
    instance_variable_set(:foo).instance_variable_set(:foo)
    #nodyna <ID:instance_variable_set-44> <not yet classified>
    instance_variable_set(:foo)_not
    not_instance_variable_set(:foo)
    not_instance_variable_set(:foo)_not
  end

  def call_instance_exec()
    #nodyna <ID:instance_exec-45> <not yet classified>
    instance_exec(:foo)
    #nodyna <ID:instance_exec-46> <not yet classified>
    #nodyna <ID:instance_exec-47> <not yet classified>
    instance_exec(:foo).instance_exec(:foo)
    #nodyna <ID:instance_exec-48> <not yet classified>
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_module_eval()
    #nodyna <ID:module_eval-49> <not yet classified>
    module_eval(:foo)
    #nodyna <ID:module_eval-50> <not yet classified>
    #nodyna <ID:module_eval-51> <not yet classified>
    module_eval(:foo).module_eval(:foo)
    #nodyna <ID:module_eval-52> <not yet classified>
    module_eval(:foo)_not
    not_module_eval(:foo)
    not_module_eval(:foo)_not
  end

  def call_send()
    #nodyna <ID:send-53> <not yet classified>
    send(:foo)
    #nodyna <ID:send-54> <not yet classified>
    #nodyna <ID:send-55> <not yet classified>
    send(:foo).send(:foo)
    #nodyna <ID:send-56> <not yet classified>
    send(:foo)_not
    not_send(:foo)
    not_send(:foo)_not
  enddef call_class_eval()
    #nodyna <ID:class_eval-57> <not yet classified>
    class_eval(:foo)
    #nodyna <ID:class_eval-58> <not yet classified>
    #nodyna <ID:class_eval-59> <not yet classified>
    class_eval(:foo).class_eval(:foo)
    #nodyna <ID:class_eval-60> <not yet classified>
    class_eval(:foo)_not
    not_class_eval(:foo)
    not_class_eval(:foo)_not
  end

  def call_class_variable_get()
    #nodyna <ID:class_variable_get-61> <not yet classified>
    class_variable_get(:foo)
    #nodyna <ID:class_variable_get-62> <not yet classified>
    #nodyna <ID:class_variable_get-63> <not yet classified>
    class_variable_get(:foo).class_variable_get(:foo)
    #nodyna <ID:class_variable_get-64> <not yet classified>
    class_variable_get(:foo)_not
    not_class_variable_get(:foo)
    not_class_variable_get(:foo)_not
  end

  def call_class_variable_set()
    #nodyna <ID:class_variable_set-65> <not yet classified>
    class_variable_set(:foo)
    #nodyna <ID:class_variable_set-66> <not yet classified>
    #nodyna <ID:class_variable_set-67> <not yet classified>
    class_variable_set(:foo).class_variable_set(:foo)
    #nodyna <ID:class_variable_set-68> <not yet classified>
    class_variable_set(:foo)_not
    not_class_variable_set(:foo)
    not_class_variable_set(:foo)_not
  end

  def call_const_set()
    #nodyna <ID:const_set-69> <not yet classified>
    const_set(:foo)
    #nodyna <ID:const_set-70> <not yet classified>
    #nodyna <ID:const_set-71> <not yet classified>
    const_set(:foo).const_set(:foo)
    #nodyna <ID:const_set-72> <not yet classified>
    const_set(:foo)_not
    not_const_set(:foo)
    not_const_set(:foo)_not
  end

  def call_const_get()
    #nodyna <ID:const_get-73> <not yet classified>
    const_get(:foo)
    #nodyna <ID:const_get-74> <not yet classified>
    #nodyna <ID:const_get-75> <not yet classified>
    const_get(:foo).const_get(:foo)
    #nodyna <ID:const_get-76> <not yet classified>
    const_get(:foo)_not
    not_const_get(:foo)
    not_const_get(:foo)_not
  end

  def call_define_method()
    #nodyna <ID:define_method-77> <not yet classified>
    define_method(:foo)
    #nodyna <ID:define_method-78> <not yet classified>
    #nodyna <ID:define_method-79> <not yet classified>
    define_method(:foo).define_method(:foo)
    #nodyna <ID:define_method-80> <not yet classified>
    define_method(:foo)_not
    not_define_method(:foo)
    not_define_method(:foo)_not
  end

  def call_eval()
    #nodyna <ID:eval-81> <not yet classified>
    eval(:foo)
    #nodyna <ID:eval-82> <not yet classified>
    #nodyna <ID:eval-83> <not yet classified>
    eval(:foo).eval(:foo)
    #nodyna <ID:eval-84> <not yet classified>
    eval(:foo)_not
    not_eval(:foo)
    not_eval(:foo)_not
  end

  def call_instance_eval()
    #nodyna <ID:instance_eval-85> <not yet classified>
    instance_eval(:foo)
    #nodyna <ID:instance_eval-86> <not yet classified>
    #nodyna <ID:instance_eval-87> <not yet classified>
    instance_eval(:foo).instance_eval(:foo)
    #nodyna <ID:instance_eval-88> <not yet classified>
    instance_eval(:foo)_not
    not_instance_eval(:foo)
    not_instance_eval(:foo)_not
  end

  def call_instance_exec()
    #nodyna <ID:instance_exec-89> <not yet classified>
    instance_exec(:foo)
    #nodyna <ID:instance_exec-90> <not yet classified>
    #nodyna <ID:instance_exec-91> <not yet classified>
    instance_exec(:foo).instance_exec(:foo)
    #nodyna <ID:instance_exec-92> <not yet classified>
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_instance_variable_get()
    #nodyna <ID:instance_variable_get-93> <not yet classified>
    instance_variable_get(:foo)
    #nodyna <ID:instance_variable_get-94> <not yet classified>
    #nodyna <ID:instance_variable_get-95> <not yet classified>
    instance_variable_get(:foo).instance_variable_get(:foo)
    #nodyna <ID:instance_variable_get-96> <not yet classified>
    instance_variable_get(:foo)_not
    not_instance_variable_get(:foo)
    not_instance_variable_get(:foo)_not
  end

  def call_instance_variable_set()
    #nodyna <ID:instance_variable_set-97> <not yet classified>
    instance_variable_set(:foo)
    #nodyna <ID:instance_variable_set-98> <not yet classified>
    #nodyna <ID:instance_variable_set-99> <not yet classified>
    instance_variable_set(:foo).instance_variable_set(:foo)
    #nodyna <ID:instance_variable_set-100> <not yet classified>
    instance_variable_set(:foo)_not
    not_instance_variable_set(:foo)
    not_instance_variable_set(:foo)_not
  end

  def call_instance_exec()
    #nodyna <ID:instance_exec-101> <not yet classified>
    instance_exec(:foo)
    #nodyna <ID:instance_exec-102> <not yet classified>
    #nodyna <ID:instance_exec-103> <not yet classified>
    instance_exec(:foo).instance_exec(:foo)
    #nodyna <ID:instance_exec-104> <not yet classified>
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_module_eval()
    #nodyna <ID:module_eval-105> <not yet classified>
    module_eval(:foo)
    #nodyna <ID:module_eval-106> <not yet classified>
    #nodyna <ID:module_eval-107> <not yet classified>
    module_eval(:foo).module_eval(:foo)
    #nodyna <ID:module_eval-108> <not yet classified>
    module_eval(:foo)_not
    not_module_eval(:foo)
    not_module_eval(:foo)_not
  end

  def call_send()
    #nodyna <ID:send-109> <not yet classified>
    send(:foo)
    #nodyna <ID:send-110> <not yet classified>
    #nodyna <ID:send-111> <not yet classified>
    send(:foo).send(:foo)
    #nodyna <ID:send-112> <not yet classified>
    send(:foo)_not
    not_send(:foo)
    not_send(:foo)_not
  end
