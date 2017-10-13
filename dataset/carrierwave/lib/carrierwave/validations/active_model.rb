
require 'active_model/validator'
require 'active_support/concern'

module CarrierWave

  module Validations
    module ActiveModel
      extend ActiveSupport::Concern

      class ProcessingValidator < ::ActiveModel::EachValidator

        def validate_each(record, attribute, value)
          #nodyna <send-2660> <SD COMPLEX (change-prone variable)>
          if e = record.send("#{attribute}_processing_error")
            message = (e.message == e.class.to_s) ? :carrierwave_processing_error : e.message
            record.errors.add(attribute, message)
          end
        end
      end

      class IntegrityValidator < ::ActiveModel::EachValidator

        def validate_each(record, attribute, value)
          #nodyna <send-2661> <SD COMPLEX (change-prone variable)>
          if e = record.send("#{attribute}_integrity_error")
            message = (e.message == e.class.to_s) ? :carrierwave_integrity_error : e.message
            record.errors.add(attribute, message)
          end
        end
      end

      class DownloadValidator < ::ActiveModel::EachValidator

        def validate_each(record, attribute, value)
          #nodyna <send-2662> <SD COMPLEX (change-prone variable)>
          if e = record.send("#{attribute}_download_error")
            message = (e.message == e.class.to_s) ? :carrierwave_download_error : e.message
            record.errors.add(attribute, message)
          end
        end
      end

      module HelperMethods

        def validates_integrity_of(*attr_names)
          validates_with IntegrityValidator, _merge_attributes(attr_names)
        end

        def validates_processing_of(*attr_names)
          validates_with ProcessingValidator, _merge_attributes(attr_names)
        end
        def validates_download_of(*attr_names)
          validates_with DownloadValidator, _merge_attributes(attr_names)
        end
      end

      included do
        extend HelperMethods
        include HelperMethods
      end
    end
  end
end
