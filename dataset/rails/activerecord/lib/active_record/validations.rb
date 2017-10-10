module ActiveRecord
  class RecordInvalid < ActiveRecordError
    attr_reader :record

    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(I18n.t(:"#{@record.class.i18n_scope}.errors.messages.record_invalid", :errors => errors, :default => :"errors.messages.record_invalid"))
    end
  end

  module Validations
    extend ActiveSupport::Concern
    include ActiveModel::Validations

    def save(options={})
      perform_validations(options) ? super : false
    end

    def save!(options={})
      perform_validations(options) ? super : raise_record_invalid
    end

    def valid?(context = nil)
      context ||= (new_record? ? :create : :update)
      output = super(context)
      errors.empty? && output
    end

    alias_method :validate, :valid?

    def validate!(context = nil)
      valid?(context) || raise_record_invalid
    end

  protected

    def raise_record_invalid
      raise(RecordInvalid.new(self))
    end

    def perform_validations(options={}) # :nodoc:
      options[:validate] == false || valid?(options[:context])
    end
  end
end

require "active_record/validations/associated"
require "active_record/validations/uniqueness"
require "active_record/validations/presence"
