require "active_support/concern"
require "active_support/inflector"

module ActiveSupport
  module Testing
    module ConstantLookup
      extend ::ActiveSupport::Concern

      module ClassMethods  # :nodoc:
        def determine_constant_from_test_name(test_name)
          names = test_name.split "::"
          while names.size > 0 do
            names.last.sub!(/Test$/, "")
            begin
              constant = names.join("::").safe_constantize
              break(constant) if yield(constant)
            ensure
              names.pop
            end
          end
        end
      end

    end
  end
end
