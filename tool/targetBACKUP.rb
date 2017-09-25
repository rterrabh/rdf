def call_class_eval()
    class_eval(:foo)
    class_eval(:foo).class_eval(:foo)
    class_eval(:foo)_not
    not_class_eval(:foo)
    not_class_eval(:foo)_not
  end

  def call_class_variable_get()
    class_variable_get(:foo)
    class_variable_get(:foo).class_variable_get(:foo)
    class_variable_get(:foo)_not
    not_class_variable_get(:foo)
    not_class_variable_get(:foo)_not
  end

  def call_class_variable_set()
    class_variable_set(:foo)
    class_variable_set(:foo).class_variable_set(:foo)
    class_variable_set(:foo)_not
    not_class_variable_set(:foo)
    not_class_variable_set(:foo)_not
  end

  def call_const_set()
    const_set(:foo)
    const_set(:foo).const_set(:foo)
    const_set(:foo)_not
    not_const_set(:foo)
    not_const_set(:foo)_not
  end

  def call_const_get()
    const_get(:foo)
    const_get(:foo).const_get(:foo)
    const_get(:foo)_not
    not_const_get(:foo)
    not_const_get(:foo)_not
  end

  def call_define_method()
    define_method(:foo)
    define_method(:foo).define_method(:foo)
    define_method(:foo)_not
    not_define_method(:foo)
    not_define_method(:foo)_not
  end

  def call_eval()
    eval(:foo)
    eval(:foo).eval(:foo)
    eval(:foo)_not
    not_eval(:foo)
    not_eval(:foo)_not
  end

  def call_instance_eval()
    instance_eval(:foo)
    instance_eval(:foo).instance_eval(:foo)
    instance_eval(:foo)_not
    not_instance_eval(:foo)
    not_instance_eval(:foo)_not
  end

  def call_instance_exec()
    instance_exec(:foo)
    instance_exec(:foo).instance_exec(:foo)
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_instance_variable_get()
    instance_variable_get(:foo)
    instance_variable_get(:foo).instance_variable_get(:foo)
    instance_variable_get(:foo)_not
    not_instance_variable_get(:foo)
    not_instance_variable_get(:foo)_not
  end

  def call_instance_variable_set()
    instance_variable_set(:foo)
    instance_variable_set(:foo).instance_variable_set(:foo)
    instance_variable_set(:foo)_not
    not_instance_variable_set(:foo)
    not_instance_variable_set(:foo)_not
  end

  def call_instance_exec()
    instance_exec(:foo)
    instance_exec(:foo).instance_exec(:foo)
    instance_exec(:foo)_not
    not_instance_exec(:foo)
    not_instance_exec(:foo)_not
  end

  def call_module_eval()
    module_eval(:foo)
    module_eval(:foo).module_eval(:foo)
    module_eval(:foo)_not
    not_module_eval(:foo)
    not_module_eval(:foo)_not
  end

  def call_send()
    send(:foo)
    send(:foo).send(:foo)
    send(:foo)_not
    not_send(:foo)
    not_send(:foo)_not
  end
