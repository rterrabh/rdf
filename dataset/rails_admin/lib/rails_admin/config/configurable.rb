module RailsAdmin
  module Config
    # A module for all configurables.

    module Configurable
      def self.included(base)
        #nodyna <ID:send-37> <send VERY HIGH ex4>
        base.send :extend, ClassMethods
      end

      def has_option?(name) # rubocop:disable PredicateName
        options = self.class.instance_variable_get('@config_options')
        options && options.key?(name)
      end

      # Register an instance option for this object only
      def register_instance_option(option_name, &default)
        scope = class << self; self; end
        self.class.register_instance_option(option_name, scope, &default)
      end

      def register_deprecated_instance_option(option_name, replacement_option_name = nil, &custom_error)
        scope = class << self; self; end
        self.class.register_deprecated_instance_option(option_name, replacement_option_name, scope, &custom_error)
      end

      module ClassMethods
        # Register an instance option. Instance option is a configuration
        # option that stores its value within an instance variable and is
        # accessed by an instance method. Both go by the name of the option.
        def register_instance_option(option_name, scope = self, &default)
          options = scope.instance_variable_get('@config_options') ||
                    scope.instance_variable_set('@config_options', {})

          option_name = option_name.to_s
          options[option_name] = nil

          # If it's a boolean create an alias for it and remove question mark
          if option_name.end_with?('?')
            #nodyna <ID:send-38> <send MEDIUM ex4>
            #nodyna <ID:define_method-2> <define_method MEDIUM ex2>
            scope.send(:define_method, "#{option_name.chop!}?") do
              #nodyna <ID:send-39> <send MEDIUM ex3>
              send(option_name)
            end
          end

          # Define getter/setter by the option name
          #nodyna <ID:send-40> <send MEDIUM ex4>
          #nodyna <ID:define_method-3> <define_method MEDIUM ex2>
          scope.send(:define_method, option_name) do |*args, &block|
            if !args[0].nil? || block # rubocop:disable NonNilCheck
              # Invocation with args --> This is the declaration of the option, i.e. setter
              instance_variable_set("@#{option_name}_registered", args[0].nil? ? block : args[0])
            else
              # Invocation without args nor block --> It's the use of the option, i.e. getter
              value = instance_variable_get("@#{option_name}_registered")
              case value
              when Proc
                # Track recursive invocation with an instance variable. This prevents run-away recursion
                # and allows configurations such as
                # label { "#{label}".upcase }
                # This will use the default definition when called recursively.
                if instance_variable_get("@#{option_name}_recurring")
                  #nodyna <ID:instance_eval-13> <instance_eval VERY HIGH ex3>
                  value = instance_eval(&default)
                else
                  instance_variable_set("@#{option_name}_recurring", true)
                  #nodyna <ID:instance_eval-14> <instance_eval VERY HIGH ex3>
                  value = instance_eval(&value)
                  instance_variable_set("@#{option_name}_recurring", false)
                end
              when nil
                #nodyna <ID:instance_eval-15> <instance_eval VERY HIGH ex3>
                value = instance_eval(&default)
              end
              value
            end
          end
        end

        def register_deprecated_instance_option(option_name, replacement_option_name = nil, scope = self)
          #nodyna <ID:send-41> <send MEDIUM ex4>
          #nodyna <ID:define_method-4> <define_method MEDIUM ex2>
          scope.send(:define_method, option_name) do |*args, &block|
            if replacement_option_name
              ActiveSupport::Deprecation.warn("The #{option_name} configuration option is deprecated, please use #{replacement_option_name}.")
              #nodyna <ID:send-42> <send MEDIUM ex3>
              send(replacement_option_name, *args, &block)
            else
              if block_given?
                yield
              else
                fail("The #{option_name} configuration option is removed without replacement.")
              end
            end
          end
        end

        # Register a class option. Class option is a configuration
        # option that stores it's value within a class object's instance variable
        # and is accessed by a class method. Both go by the name of the option.
        def register_class_option(option_name, &default)
          scope = class << self; self; end
          register_instance_option(option_name, scope, &default)
        end
      end
    end
  end
end