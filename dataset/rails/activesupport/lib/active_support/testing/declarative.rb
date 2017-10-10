module ActiveSupport
  module Testing
    module Declarative
      unless defined?(Spec)
        def test(name, &block)
          test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
          defined = method_defined? test_name
          raise "#{test_name} is already defined in #{self}" if defined
          if block_given?
            #nodyna <define_method-1130> <DM COMPLEX (events)>
            define_method(test_name, &block)
          else
            #nodyna <define_method-1131> <DM COMPLEX (events)>
            define_method(test_name) do
              flunk "No implementation provided for #{name}"
            end
          end
        end
      end
    end
  end
end
