class Object
  def instance_values
    #nodyna <instance_variable_get-1091> <not yet classified>
    Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] }]
  end

  def instance_variable_names
    instance_variables.map { |var| var.to_s }
  end
end
