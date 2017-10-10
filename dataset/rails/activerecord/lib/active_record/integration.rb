require 'active_support/core_ext/string/filters'

module ActiveRecord
  module Integration
    extend ActiveSupport::Concern

    included do
      class_attribute :cache_timestamp_format, :instance_writer => false
      self.cache_timestamp_format = :nsec
    end

    def to_param
      id && id.to_s # Be sure to stringify the id for routes
    end

    def cache_key(*timestamp_names)
      case
      when new_record?
        "#{model_name.cache_key}/new"
      when timestamp_names.any?
        timestamp = max_updated_column_timestamp(timestamp_names)
        timestamp = timestamp.utc.to_s(cache_timestamp_format)
        "#{model_name.cache_key}/#{id}-#{timestamp}"
      when timestamp = max_updated_column_timestamp
        timestamp = timestamp.utc.to_s(cache_timestamp_format)
        "#{model_name.cache_key}/#{id}-#{timestamp}"
      else
        "#{model_name.cache_key}/#{id}"
      end
    end

    module ClassMethods
      def to_param(method_name = nil)
        if method_name.nil?
          super()
        else
          #nodyna <define_method-797> <DM COMPLEX (events)>
          define_method :to_param do
            if (default = super()) &&
                 #nodyna <send-798> <SD COMPLEX (change-prone variables)>
                 (result = send(method_name).to_s).present? &&
                   (param = result.squish.truncate(20, separator: /\s/, omission: nil).parameterize).present?
              "#{default}-#{param}"
            else
              default
            end
          end
        end
      end
    end
  end
end
