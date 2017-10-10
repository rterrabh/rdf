module CanCan
  module ModelAdapters
    class AbstractAdapter
      def self.inherited(subclass)
        @subclasses ||= []
        @subclasses << subclass
      end

      def self.adapter_class(model_class)
        @subclasses.detect { |subclass| subclass.for_class?(model_class) } || DefaultAdapter
      end

      def self.for_class?(member_class)
        false # override in subclass
      end

      def self.find(model_class, id)
        model_class.find(id)
      end

      def self.override_conditions_hash_matching?(subject, conditions)
        false
      end

      def self.matches_conditions_hash?(subject, conditions)
        raise NotImplemented, "This model adapter does not support matching on a conditions hash."
      end

      def self.override_condition_matching?(subject, name, value)
        false
      end

      def self.matches_condition?(subject, name, value)
        raise NotImplemented, "This model adapter does not support matching on a specific condition."
      end

      def initialize(model_class, rules)
        @model_class = model_class
        @rules = rules
      end

      def database_records
        raise NotImplemented, "This model adapter does not support fetching records from the database."
      end
    end
  end
end
