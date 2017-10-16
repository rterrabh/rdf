module RailsAdmin
  module Config

    module Configurable
      def self.included(base)
        #nodyna <send-1387> <SD COMPLEX (private methods)>
        base.send :extend, ClassMethods
      end

      def has_option?(name) # rubocop:disable PredicateName
        #nodyna <instance_variable_get-1388> <IVG MODERATE (private access)>
        options = self.class.instance_variable_get('@config_options')
        options && options.key?(name)
      end

      def register_instance_option(option_name, &default)
        scope = class << self; self; end
        self.class.register_instance_option(option_name, scope, &default)
      end

      def register_deprecated_instance_option(option_name, replacement_option_name = nil, &custom_error)
        scope = class << self; self; end
        self.class.register_deprecated_instance_option(option_name, replacement_option_name, scope, &custom_error)
      end

      module ClassMethods
        def register_instance_option(option_name, scope = self, &default)
          #nodyna <instance_variable_get-1389> <IVG MODERATE (private access)>
          options = scope.instance_variable_get('@config_options') ||
                    #nodyna <instance_variable_set-1390> <IVS MODERATE (private access)>
                    scope.instance_variable_set('@config_options', {})

          option_name = option_name.to_s
          options[option_name] = nil

          if option_name.end_with?('?')
            #nodyna <send-1391> <SD MODERATE (private methods)>
            #nodyna <define_method-1392> <DM MODERATE (events)>
            scope.send(:define_method, "#{option_name.chop!}?") do
              #nodyna <send-1393> <SD MODERATE (change-prone variables)>
              send(option_name)
            end
          end

          #nodyna <send-1394> <SD MODERATE (private methods)>
          #nodyna <define_method-1395> <DM MODERATE (events)>
          scope.send(:define_method, option_name) do |*args, &block|
            if !args[0].nil? || block # rubocop:disable NonNilCheck
              #nodyna <instance_variable_set-1396> <IVS MODERATE (change-prone variable)>
              instance_variable_set("@#{option_name}_registered", args[0].nil? ? block : args[0])
            else
              #nodyna <instance_variable_get-1397> <IVG MODERATE (change-prone variable)>
              value = instance_variable_get("@#{option_name}_registered")
              case value
              when Proc
                #nodyna <instance_variable_get-1398> <IVG MODERATE (change-prone variable)>
                if instance_variable_get("@#{option_name}_recurring")
                  #nodyna <instance_eval-1399> <IEV COMPLEX (block execution)>
                  value = instance_eval(&default)
                else
                  #nodyna <instance_variable_set-1400> <IVS MODERATE (change-prone variable)>
                  instance_variable_set("@#{option_name}_recurring", true)
                  #nodyna <instance_eval-1401> <IEV COMPLEX (block execution)>
                  value = instance_eval(&value)
                  #nodyna <instance_variable_set-1402> <IVS MODERATE (change-prone variable)>
                  instance_variable_set("@#{option_name}_recurring", false)
                end
              when nil
                #nodyna <instance_eval-1403> <IEV COMPLEX (block execution)>
                value = instance_eval(&default)
              end
              value
            end
          end
        end

        def register_deprecated_instance_option(option_name, replacement_option_name = nil, scope = self)
          #nodyna <send-1404> <SD MODERATE (private methods)>
          #nodyna <define_method-1405> <DM MODERATE (events)>
          scope.send(:define_method, option_name) do |*args, &block|
            if replacement_option_name
              ActiveSupport::Deprecation.warn("The #{option_name} configuration option is deprecated, please use #{replacement_option_name}.")
              #nodyna <send-1406> <SD MODERATE (change-prone variables)>
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

        def register_class_option(option_name, &default)
          scope = class << self; self; end
          register_instance_option(option_name, scope, &default)
        end
      end
    end
  end
end
