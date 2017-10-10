require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  class Deprecation
    module MethodWrapper
      def deprecate_methods(target_module, *method_names)
        options = method_names.extract_options!
        deprecator = options.delete(:deprecator) || ActiveSupport::Deprecation.instance
        method_names += options.keys

        method_names.each do |method_name|
          target_module.alias_method_chain(method_name, :deprecation) do |target, punctuation|
            #nodyna <send-1015> <SD COMPLEX (private methods)>
            #nodyna <define_method-1016> <DM COMPLEX (events)>
            target_module.send(:define_method, "#{target}_with_deprecation#{punctuation}") do |*args, &block|
              deprecator.deprecation_warning(method_name, options[method_name])
              #nodyna <send-1017> <SD COMPLEX (change-prone variables)>
              send(:"#{target}_without_deprecation#{punctuation}", *args, &block)
            end
          end
        end
      end
    end
  end
end
