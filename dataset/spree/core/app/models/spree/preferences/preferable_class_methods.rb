module Spree::Preferences
  module PreferableClassMethods

    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default)
      default = options[:default]
      default = ->{ options[:default] } unless default.is_a?(Proc)

      #nodyna <define_method-2512> <DM MODERATE (events)>
      define_method preference_getter_method(name) do
        preferences.fetch(name) do
          default.call
        end
      end

      #nodyna <define_method-2513> <DM MODERATE (events)>
      define_method preference_setter_method(name) do |value|
        value = convert_preference_value(value, type)
        preferences[name] = value

        preferences_will_change! if respond_to?(:preferences_will_change!)
      end

      #nodyna <define_method-2514> <DM COMPLEX (events)>
      define_method preference_default_getter_method(name), &default

      #nodyna <define_method-2515> <DM MODERATE (events)>
      define_method preference_type_getter_method(name) do
        type
      end
    end

    def preference_getter_method(name)
      "preferred_#{name}".to_sym
    end

    def preference_setter_method(name)
       "preferred_#{name}=".to_sym
    end

    def preference_default_getter_method(name)
      "preferred_#{name}_default".to_sym
    end

    def preference_type_getter_method(name)
      "preferred_#{name}_type".to_sym
    end
  end
end
