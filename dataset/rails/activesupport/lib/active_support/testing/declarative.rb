module ActiveSupport
  module Testing
    module Declarative
      unless defined?(Spec)
        # Helper to define a test method using a String. Under the hood, it replaces
        # spaces with underscores and defines the test method.
        #
        #   test "verify something" do
        #     ...
        #   end
        def test(name, &block)
          test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
          defined = method_defined? test_name
          raise "#{test_name} is already defined in #{self}" if defined
          if block_given?
            #nodyna <ID:define_method-64> <define_method VERY HIGH ex2>
            define_method(test_name, &block)
          else
            #nodyna <ID:define_method-65> <define_method VERY HIGH ex2>
            define_method(test_name) do
              flunk "No implementation provided for #{name}"
            end
          end
        end
      end
    end
  end
end