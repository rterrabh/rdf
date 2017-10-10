require 'active_support/core_ext/module/concerning'

module Kernel
  def concern(topic, &module_definition)
    Object.concern topic, &module_definition
  end
end
