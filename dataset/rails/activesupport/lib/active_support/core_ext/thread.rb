class Thread
  LOCK = Mutex.new # :nodoc:

  def thread_variable_get(key)
    _locals[key.to_sym]
  end

  def thread_variable_set(key, value)
    _locals[key.to_sym] = value
  end

  def thread_variables
    _locals.keys
  end

  def thread_variable?(key)
    _locals.has_key?(key.to_sym)
  end

  def freeze
    _locals.freeze
    super
  end

  private

  def _locals
    if defined?(@_locals)
      @_locals
    else
      LOCK.synchronize { @_locals ||= {} }
    end
  end
end unless Thread.instance_methods.include?(:thread_variable_set)
