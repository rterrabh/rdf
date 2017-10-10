class Module
  def remove_possible_method(method)
    if method_defined?(method) || private_method_defined?(method)
      undef_method(method)
    end
  end

  def redefine_method(method, &block)
    remove_possible_method(method)
    #nodyna <define_method-1047> <DM COMPLEX (events)>
    define_method(method, &block)
  end
end
