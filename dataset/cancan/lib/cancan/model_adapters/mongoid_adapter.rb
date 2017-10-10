module CanCan
  module ModelAdapters
    class MongoidAdapter < AbstractAdapter
      def self.for_class?(model_class)
        model_class <= Mongoid::Document
      end

      def self.override_conditions_hash_matching?(subject, conditions)
        conditions.any? do |k,v|
          key_is_not_symbol = lambda { !k.kind_of?(Symbol) }
          subject_value_is_array = lambda do
            #nodyna <send-2620> <not yet classified>
            subject.respond_to?(k) && subject.send(k).is_a?(Array)
          end

          key_is_not_symbol.call || subject_value_is_array.call
        end
      end

      def self.matches_conditions_hash?(subject, conditions)
        subject.matches?( subject.class.where(conditions).selector )
      end

      def database_records
        if @rules.size == 0
          @model_class.where(:_id => {'$exists' => false, '$type' => 7}) # return no records in Mongoid
        elsif @rules.size == 1 && @rules[0].conditions.is_a?(Mongoid::Criteria)
          @rules[0].conditions
        else
          rules = @rules.reject { |rule| rule.conditions.empty? && rule.base_behavior }
          process_can_rules = @rules.count == rules.count

          rules.inject(@model_class.all) do |records, rule|
            if process_can_rules && rule.base_behavior
              records.or rule.conditions
            elsif !rule.base_behavior
              records.excludes rule.conditions
            else
              records
            end
          end
        end
      end
    end
  end
end

module Mongoid::Document::ClassMethods
  include CanCan::ModelAdditions::ClassMethods
end
