module SimpleForm
  module I18nCache
    def i18n_cache(key)
      get_i18n_cache(key)[I18n.locale] ||= yield.freeze
    end

    def get_i18n_cache(key)
      if class_variable_defined?(:"@@#{key}")
        #nodyna <class_variable_get-3049> <CVG MODERATE (change-prone variables)>
        class_variable_get(:"@@#{key}")
      else
        reset_i18n_cache(key)
      end
    end

    def reset_i18n_cache(key)
      #nodyna <class_variable_set-3050> <CVS MODERATE (change-prone variables)>
      class_variable_set(:"@@#{key}", {})
    end
  end
end
