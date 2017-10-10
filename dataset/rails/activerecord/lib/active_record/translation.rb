module ActiveRecord
  module Translation
    include ActiveModel::Translation

    def lookup_ancestors #:nodoc:
      klass = self
      classes = [klass]
      return classes if klass == ActiveRecord::Base

      while klass != klass.base_class
        classes << klass = klass.superclass
      end
      classes
    end

    def i18n_scope #:nodoc:
      :activerecord
    end
  end
end
