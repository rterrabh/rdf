module CanCan
  module ModelAdapters
    class ActiveRecordAdapter < AbstractAdapter
      def self.for_class?(model_class)
        model_class <= ActiveRecord::Base
      end

      def self.override_condition_matching?(subject, name, value)
        name.kind_of?(MetaWhere::Column) if defined? MetaWhere
      end

      def self.matches_condition?(subject, name, value)
        #nodyna <send-2617> <not yet classified>
        subject_value = subject.send(name.column)
        if name.method.to_s.ends_with? "_any"
          value.any? { |v| meta_where_match? subject_value, name.method.to_s.sub("_any", ""), v }
        elsif name.method.to_s.ends_with? "_all"
          value.all? { |v| meta_where_match? subject_value, name.method.to_s.sub("_all", ""), v }
        else
          meta_where_match? subject_value, name.method, value
        end
      end

      def self.meta_where_match?(subject_value, method, value)
        case method.to_sym
        when :eq      then subject_value == value
        when :not_eq  then subject_value != value
        when :in      then value.include?(subject_value)
        when :not_in  then !value.include?(subject_value)
        when :lt      then subject_value < value
        when :lteq    then subject_value <= value
        when :gt      then subject_value > value
        when :gteq    then subject_value >= value
        when :matches then subject_value =~ Regexp.new("^" + Regexp.escape(value).gsub("%", ".*") + "$", true)
        when :does_not_match then !meta_where_match?(subject_value, :matches, value)
        else raise NotImplemented, "The #{method} MetaWhere condition is not supported."
        end
      end

      def conditions
        if @rules.size == 1 && @rules.first.base_behavior
          tableized_conditions(@rules.first.conditions).dup
        else
          @rules.reverse.inject(false_sql) do |sql, rule|
            merge_conditions(sql, tableized_conditions(rule.conditions).dup, rule.base_behavior)
          end
        end
      end

      def tableized_conditions(conditions, model_class = @model_class)
        return conditions unless conditions.kind_of? Hash
        conditions.inject({}) do |result_hash, (name, value)|
          if value.kind_of? Hash
            value = value.dup
            association_class = model_class.reflect_on_association(name).class_name.constantize
            nested = value.inject({}) do |nested,(k,v)|
              if v.kind_of? Hash
                value.delete(k)
                nested[k] = v
              else
                name = model_class.reflect_on_association(name).table_name.to_sym
                result_hash[name] = value
              end
              nested
            end
            result_hash.merge!(tableized_conditions(nested,association_class))
          else
            result_hash[name] = value
          end
          result_hash
        end
      end

      def joins
        joins_hash = {}
        @rules.each do |rule|
          merge_joins(joins_hash, rule.associations_hash)
        end
        clean_joins(joins_hash) unless joins_hash.empty?
      end

      def database_records
        if override_scope
          @model_class.scoped.merge(override_scope)
        elsif @model_class.respond_to?(:where) && @model_class.respond_to?(:joins)
          mergeable_conditions = @rules.select {|rule| rule.unmergeable? }.blank?
          if mergeable_conditions
            @model_class.where(conditions).joins(joins)
          else
            @model_class.where(*(@rules.map(&:conditions))).joins(joins)
          end
        else
          @model_class.scoped(:conditions => conditions, :joins => joins)
        end
      end

      private

      def override_scope
        conditions = @rules.map(&:conditions).compact
        if defined?(ActiveRecord::Relation) && conditions.any? { |c| c.kind_of?(ActiveRecord::Relation) }
          if conditions.size == 1
            conditions.first
          else
            rule = @rules.detect { |rule| rule.conditions.kind_of?(ActiveRecord::Relation) }
            raise Error, "Unable to merge an Active Record scope with other conditions. Instead use a hash or SQL for #{rule.actions.first} #{rule.subjects.first} ability."
          end
        end
      end

      def merge_conditions(sql, conditions_hash, behavior)
        if conditions_hash.blank?
          behavior ? true_sql : false_sql
        else
          conditions = sanitize_sql(conditions_hash)
          case sql
          when true_sql
            behavior ? true_sql : "not (#{conditions})"
          when false_sql
            behavior ? conditions : false_sql
          else
            behavior ? "(#{conditions}) OR (#{sql})" : "not (#{conditions}) AND (#{sql})"
          end
        end
      end

      def false_sql
        sanitize_sql(['?=?', true, false])
      end

      def true_sql
        sanitize_sql(['?=?', true, true])
      end

      def sanitize_sql(conditions)
        #nodyna <send-2618> <not yet classified>
        @model_class.send(:sanitize_sql, conditions)
      end

      def merge_joins(base, add)
        add.each do |name, nested|
          if base[name].is_a?(Hash)
            merge_joins(base[name], nested) unless nested.empty?
          else
            base[name] = nested
          end
        end
      end

      def clean_joins(joins_hash)
        joins = []
        joins_hash.each do |name, nested|
          joins << (nested.empty? ? name : {name => clean_joins(nested)})
        end
        joins
      end
    end
  end
end

#nodyna <class_eval-2619> <not yet classified>
ActiveRecord::Base.class_eval do
  include CanCan::ModelAdditions
end