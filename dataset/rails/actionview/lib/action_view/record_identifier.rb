require 'active_support/core_ext/module'
require 'action_view/model_naming'

module ActionView
  module RecordIdentifier
    extend self
    extend ModelNaming

    include ModelNaming

    JOIN = '_'.freeze
    NEW = 'new'.freeze

    def dom_class(record_or_class, prefix = nil)
      singular = model_name_from_record_or_class(record_or_class).param_key
      prefix ? "#{prefix}#{JOIN}#{singular}" : singular
    end

    def dom_id(record, prefix = nil)
      if record_id = record_key_for_dom_id(record)
        "#{dom_class(record, prefix)}#{JOIN}#{record_id}"
      else
        dom_class(record, prefix || NEW)
      end
    end

  protected

    def record_key_for_dom_id(record)
      key = convert_to_model(record).to_key
      key ? key.join('_') : key
    end
  end
end
