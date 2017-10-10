module Rake

  module Cloneable # :nodoc:
    def initialize_copy(source)
      super
      source.instance_variables.each do |var|
        #nodyna <instance_variable_get-2041> <not yet classified>
        src_value  = source.instance_variable_get(var)
        value = src_value.clone rescue src_value
        #nodyna <instance_variable_set-2042> <not yet classified>
        instance_variable_set(var, value)
      end
    end
  end
end
