module ActiveModel
  module Validations
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :validation,
                         terminator: ->(_,result) { result == false },
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name]
      end

      module ClassMethods
        def before_validation(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array(options[:if])
            options[:on] = Array(options[:on])
            options[:if].unshift ->(o) {
              options[:on].include? o.validation_context
            }
          end
          set_callback(:validation, :before, *args, &block)
        end

        def after_validation(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array(options[:if])
          if options[:on]
            options[:on] = Array(options[:on])
            options[:if].unshift ->(o) {
              options[:on].include? o.validation_context
            }
          end
          set_callback(:validation, :after, *(args << options), &block)
        end
      end

    protected

      def run_validations! #:nodoc:
        _run_validation_callbacks { super }
      end
    end
  end
end
