module ActiveModel
  module Conversion
    extend ActiveSupport::Concern

    def to_model
      self
    end

    def to_key
      key = respond_to?(:id) && id
      key ? [key] : nil
    end

    def to_param
      (persisted? && key = to_key) ? key.join('-') : nil
    end

    def to_partial_path
      self.class._to_partial_path
    end

    module ClassMethods #:nodoc:
      def _to_partial_path #:nodoc:
        @_to_partial_path ||= begin
          element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(name))
          collection = ActiveSupport::Inflector.tableize(name)
          "#{collection}/#{element}".freeze
        end
      end
    end
  end
end
