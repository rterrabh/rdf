module Rake

  module Cloneable # :nodoc:
    def initialize_copy(source)
      super
      source.instance_variables.each do |var|
        #nodyna <instance_variable_get-2041> <IVG COMPLEX (array)>
        src_value  = source.instance_variable_get(var)
        value = src_value.clone rescue src_value
        #nodyna <instance_variable_set-2042> <IVS COMPLEX (array)>
        instance_variable_set(var, value)
      end
    end
  end
end
