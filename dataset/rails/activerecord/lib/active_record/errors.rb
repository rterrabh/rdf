module ActiveRecord

  class ActiveRecordError < StandardError
  end

  class SubclassNotFound < ActiveRecordError #:nodoc:
  end

  class AssociationTypeMismatch < ActiveRecordError
  end

  class SerializationTypeMismatch < ActiveRecordError
  end

  class AdapterNotSpecified < ActiveRecordError
  end

  class AdapterNotFound < ActiveRecordError
  end

  class ConnectionNotEstablished < ActiveRecordError
  end

  class RecordNotFound < ActiveRecordError
  end

  class RecordNotSaved < ActiveRecordError
    attr_reader :record

    def initialize(message, record = nil)
      @record = record
      super(message)
    end
  end

  class RecordNotDestroyed < ActiveRecordError
    attr_reader :record

    def initialize(message, record = nil)
      @record = record
      super(message)
    end
  end

  class StatementInvalid < ActiveRecordError
    attr_reader :original_exception

    def initialize(message, original_exception = nil)
      super(message)
      @original_exception = original_exception
    end
  end

  class WrappedDatabaseException < StatementInvalid
  end

  class RecordNotUnique < WrappedDatabaseException
  end

  class InvalidForeignKey < WrappedDatabaseException
  end

  class PreparedStatementInvalid < ActiveRecordError
  end

  class NoDatabaseError < StatementInvalid
  end

  class StaleObjectError < ActiveRecordError
    attr_reader :record, :attempted_action

    def initialize(record, attempted_action)
      super("Attempted to #{attempted_action} a stale object: #{record.class.name}")
      @record = record
      @attempted_action = attempted_action
    end

  end

  class ConfigurationError < ActiveRecordError
  end

  class ReadOnlyRecord < ActiveRecordError
  end

  class Rollback < ActiveRecordError
  end

  class DangerousAttributeError < ActiveRecordError
  end

  class UnknownAttributeError < NoMethodError

    attr_reader :record, :attribute

    def initialize(record, attribute)
      @record = record
      @attribute = attribute.to_s
      super("unknown attribute '#{attribute}' for #{@record.class}.")
    end

  end

  class AttributeAssignmentError < ActiveRecordError
    attr_reader :exception, :attribute

    def initialize(message, exception, attribute)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  class MultiparameterAssignmentErrors < ActiveRecordError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end
  end

  class UnknownPrimaryKey < ActiveRecordError
    attr_reader :model

    def initialize(model)
      super("Unknown primary key for table #{model.table_name} in model #{model}.")
      @model = model
    end

  end

  class ImmutableRelation < ActiveRecordError
  end

  class TransactionIsolationError < ActiveRecordError
  end
end
