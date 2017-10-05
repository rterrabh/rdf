require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  class Deprecation
    module MethodWrapper
      # Declare that a method has been deprecated.
      #
      #   module Fred
      #     extend self
      #
      #     def foo; end
      #     def bar; end
      #     def baz; end
      #   end
      #
      #   ActiveSupport::Deprecation.deprecate_methods(Fred, :foo, bar: :qux, baz: 'use Bar#baz instead')
      #   # => [:foo, :bar, :baz]
      #
      #   Fred.foo
      #   # => "DEPRECATION WARNING: foo is deprecated and will be removed from Rails 4.1."
      #
      #   Fred.bar
      #   # => "DEPRECATION WARNING: bar is deprecated and will be removed from Rails 4.1 (use qux instead)."
      #
      #   Fred.baz
      #   # => "DEPRECATION WARNING: baz is deprecated and will be removed from Rails 4.1 (use Bar#baz instead)."
      def deprecate_methods(target_module, *method_names)
        options = method_names.extract_options!
        deprecator = options.delete(:deprecator) || ActiveSupport::Deprecation.instance
        method_names += options.keys

        method_names.each do |method_name|
          target_module.alias_method_chain(method_name, :deprecation) do |target, punctuation|
            #nodyna <ID:send-221> <SD COMPLEX (private methods)>
            #nodyna <ID:define_method-48> <DM COMPLEX (events)>
            target_module.send(:define_method, "#{target}_with_deprecation#{punctuation}") do |*args, &block|
              deprecator.deprecation_warning(method_name, options[method_name])
              #nodyna <ID:send-222> <SD COMPLEX (change-prone variables)>
              send(:"#{target}_without_deprecation#{punctuation}", *args, &block)
            end
          end
        end
      end
    end
  end
end
