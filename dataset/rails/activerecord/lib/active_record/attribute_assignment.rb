require 'active_model/forbidden_attributes_protection'

module ActiveRecord
  module AttributeAssignment
    extend ActiveSupport::Concern
    include ActiveModel::ForbiddenAttributesProtection

    def assign_attributes(new_attributes)
      if !new_attributes.respond_to?(:stringify_keys)
        raise ArgumentError, "When assigning attributes, you must pass a hash as an argument."
      end
      return if new_attributes.blank?

      attributes                  = new_attributes.stringify_keys
      multi_parameter_attributes  = []
      nested_parameter_attributes = []

      attributes = sanitize_for_mass_assignment(attributes)

      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        elsif v.is_a?(Hash)
          nested_parameter_attributes << [ k, v ]
        else
          _assign_attribute(k, v)
        end
      end

      assign_nested_parameter_attributes(nested_parameter_attributes) unless nested_parameter_attributes.empty?
      assign_multiparameter_attributes(multi_parameter_attributes) unless multi_parameter_attributes.empty?
    end

    alias attributes= assign_attributes

    private

    def _assign_attribute(k, v)
      #nodyna <send-835> <SD COMPLEX (change-prone variables)>
      public_send("#{k}=", v)
    rescue NoMethodError, NameError
      if respond_to?("#{k}=")
        raise
      else
        raise UnknownAttributeError.new(self, k)
      end
    end

    def assign_nested_parameter_attributes(pairs)
      pairs.each { |k, v| _assign_attribute(k, v) }
    end

    def assign_multiparameter_attributes(pairs)
      execute_callstack_for_multiparameter_attributes(
        extract_callstack_for_multiparameter_attributes(pairs)
      )
    end

    def execute_callstack_for_multiparameter_attributes(callstack)
      errors = []
      callstack.each do |name, values_with_empty_parameters|
        begin
          #nodyna <send-836> <SD COMPLEX (array)>
          send("#{name}=", MultiparameterAttribute.new(self, name, values_with_empty_parameters).read_value)
        rescue => ex
          errors << AttributeAssignmentError.new("error on assignment #{values_with_empty_parameters.values.inspect} to #{name} (#{ex.message})", ex, name)
        end
      end
      unless errors.empty?
        error_descriptions = errors.map { |ex| ex.message }.join(",")
        raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes [#{error_descriptions}]"
      end
    end

    def extract_callstack_for_multiparameter_attributes(pairs)
      attributes = {}

      pairs.each do |(multiparameter_name, value)|
        attribute_name = multiparameter_name.split("(").first
        attributes[attribute_name] ||= {}

        parameter_value = value.empty? ? nil : type_cast_attribute_value(multiparameter_name, value)
        attributes[attribute_name][find_parameter_position(multiparameter_name)] ||= parameter_value
      end

      attributes
    end

    def type_cast_attribute_value(multiparameter_name, value)
      #nodyna <send-837> <SD COMPLEX (change-prone variables)>
      multiparameter_name =~ /\([0-9]*([if])\)/ ? value.send("to_" + $1) : value
    end

    def find_parameter_position(multiparameter_name)
      multiparameter_name.scan(/\(([0-9]*).*\)/).first.first.to_i
    end

    class MultiparameterAttribute #:nodoc:
      attr_reader :object, :name, :values, :cast_type

      def initialize(object, name, values)
        @object = object
        @name   = name
        @values = values
      end

      def read_value
        return if values.values.compact.empty?

        @cast_type = object.type_for_attribute(name)
        klass = cast_type.klass

        if klass == Time
          read_time
        elsif klass == Date
          read_date
        else
          read_other
        end
      end

      private

      def instantiate_time_object(set_values)
        #nodyna <send-838> <SD EASY (private methods)>
        if object.class.send(:create_time_zone_conversion_attribute?, name, cast_type)
          Time.zone.local(*set_values)
        else
          #nodyna <send-839> <SD COMPLEX (change-prone variables)>
          Time.send(object.class.default_timezone, *set_values)
        end
      end

      def read_time
        if cast_type.type == :time
          { 1 => 1970, 2 => 1, 3 => 1 }.each do |key,value|
            values[key] ||= value
          end
        else
          validate_required_parameters!([1,2,3])

          return if blank_date_parameter?
        end

        max_position = extract_max_param(6)
        set_values   = values.values_at(*(1..max_position))
        (3..5).each { |i| set_values[i] = set_values[i].presence || 0 }
        instantiate_time_object(set_values)
      end

      def read_date
        return if blank_date_parameter?
        set_values = values.values_at(1,2,3)
        begin
          Date.new(*set_values)
        rescue ArgumentError # if Date.new raises an exception on an invalid date
          instantiate_time_object(set_values).to_date # we instantiate Time object and convert it back to a date thus using Time's logic in handling invalid dates
        end
      end

      def read_other
        max_position = extract_max_param
        positions    = (1..max_position)
        validate_required_parameters!(positions)

        values.slice(*positions)
      end

      def blank_date_parameter?
        (1..3).any? { |position| values[position].blank? }
      end

      def validate_required_parameters!(positions)
        if missing_parameter = positions.detect { |position| !values.key?(position) }
          raise ArgumentError.new("Missing Parameter - #{name}(#{missing_parameter})")
        end
      end

      def extract_max_param(upper_cap = 100)
        [values.keys.max, upper_cap].min
      end
    end
  end
end
