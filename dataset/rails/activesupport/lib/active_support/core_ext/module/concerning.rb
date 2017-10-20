require 'active_support/concern'

class Module
  module Concerning
    def concerning(topic, &block)
      include concern(topic, &block)
    end

    def concern(topic, &module_definition)
      #nodyna <const_set-1051> <CS COMPLEX (change-prone variable)>
      const_set topic, Module.new {
        extend ::ActiveSupport::Concern
        #nodyna <module_eval-1052> <ME COMPLEX (block execution)>
        module_eval(&module_definition)
      }
    end
  end
  include Concerning
end
