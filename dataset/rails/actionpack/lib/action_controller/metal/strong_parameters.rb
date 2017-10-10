require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/string/filters'
require 'active_support/deprecation'
require 'active_support/rescuable'
require 'action_dispatch/http/upload'
require 'stringio'
require 'set'

module ActionController
  class ParameterMissing < KeyError
    attr_reader :param # :nodoc:

    def initialize(param) # :nodoc:
      @param = param
      super("param is missing or the value is empty: #{param}")
    end
  end

  class UnpermittedParameters < IndexError
    attr_reader :params # :nodoc:

    def initialize(params) # :nodoc:
      @params = params
      super("found unpermitted parameter#{'s' if params.size > 1 }: #{params.join(", ")}")
    end
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    cattr_accessor :permit_all_parameters, instance_accessor: false
    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    cattr_accessor :always_permitted_parameters
    self.always_permitted_parameters = %w( controller action )

    def self.const_missing(const_name)
      super unless const_name == :NEVER_UNPERMITTED_PARAMS
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        `ActionController::Parameters::NEVER_UNPERMITTED_PARAMS` has been deprecated.
        Use `ActionController::Parameters.always_permitted_parameters` instead.
      MSG

      always_permitted_parameters
    end

    def initialize(attributes = nil)
      super(attributes)
      @permitted = self.class.permit_all_parameters
    end

    def to_h
      if permitted?
        to_hash
      else
        slice(*self.class.always_permitted_parameters).permit!.to_h
      end
    end

    def to_unsafe_h
      to_hash
    end
    alias_method :to_unsafe_hash, :to_unsafe_h

    def each_pair(&block)
      super do |key, value|
        convert_hashes_to_parameters(key, value)
      end

      super
    end

    alias_method :each, :each_pair

    def converted_arrays
      @converted_arrays ||= Set.new
    end

    def permitted?
      @permitted
    end

    def permit!
      each_pair do |key, value|
        Array.wrap(value).each do |v|
          v.permit! if v.respond_to? :permit!
        end
      end

      @permitted = true
      self
    end

    def require(key)
      value = self[key]
      if value.present? || value == false
        value
      else
        raise ParameterMissing.new(key)
      end
    end

    alias :required :require

    def permit(*filters)
      params = self.class.new

      filters.flatten.each do |filter|
        case filter
        when Symbol, String
          permitted_scalar_filter(params, filter)
        when Hash then
          hash_filter(params, filter)
        end
      end

      unpermitted_parameters!(params) if self.class.action_on_unpermitted_parameters

      params.permit!
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key, *args)
      convert_hashes_to_parameters(key, super, false)
    rescue KeyError
      raise ActionController::ParameterMissing.new(key)
    end

    def slice(*keys)
      new_instance_with_inherited_permitted_status(super)
    end

    def extract!(*keys)
      new_instance_with_inherited_permitted_status(super)
    end

    def transform_values
      if block_given?
        new_instance_with_inherited_permitted_status(super)
      else
        super
      end
    end

    def transform_keys # :nodoc:
      if block_given?
        new_instance_with_inherited_permitted_status(super)
      else
        super
      end
    end

    def delete(key, &block)
      convert_hashes_to_parameters(key, super, false)
    end

    def select!(&block)
      convert_value_to_parameters(super)
    end

    def dup
      super.tap do |duplicate|
        duplicate.permitted = @permitted
      end
    end

    protected
      def permitted=(new_permitted)
        @permitted = new_permitted
      end

    private
      def new_instance_with_inherited_permitted_status(hash)
        self.class.new(hash).tap do |new_instance|
          new_instance.permitted = @permitted
        end
      end

      def convert_hashes_to_parameters(key, value, assign_if_converted=true)
        converted = convert_value_to_parameters(value)
        self[key] = converted if assign_if_converted && !converted.equal?(value)
        converted
      end

      def convert_value_to_parameters(value)
        if value.is_a?(Array) && !converted_arrays.member?(value)
          converted = value.map { |_| convert_value_to_parameters(_) }
          converted_arrays << converted
          converted
        elsif value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          self.class.new(value)
        end
      end

      def each_element(object)
        if object.is_a?(Array)
          object.map { |el| yield el }.compact
        elsif fields_for_style?(object)
          hash = object.class.new
          object.each { |k,v| hash[k] = yield v }
          hash
        else
          yield object
        end
      end

      def fields_for_style?(object)
        object.is_a?(Hash) && object.all? { |k, v| k =~ /\A-?\d+\z/ && v.is_a?(Hash) }
      end

      def unpermitted_parameters!(params)
        unpermitted_keys = unpermitted_keys(params)
        if unpermitted_keys.any?
          case self.class.action_on_unpermitted_parameters
          when :log
            name = "unpermitted_parameters.action_controller"
            ActiveSupport::Notifications.instrument(name, keys: unpermitted_keys)
          when :raise
            raise ActionController::UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        self.keys - params.keys - self.always_permitted_parameters
      end


      PERMITTED_SCALAR_TYPES = [
        String,
        Symbol,
        NilClass,
        Numeric,
        TrueClass,
        FalseClass,
        Date,
        Time,
        StringIO,
        IO,
        ActionDispatch::Http::UploadedFile,
        Rack::Test::UploadedFile,
      ]

      def permitted_scalar?(value)
        PERMITTED_SCALAR_TYPES.any? {|type| value.is_a?(type)}
      end

      def permitted_scalar_filter(params, key)
        if has_key?(key) && permitted_scalar?(self[key])
          params[key] = self[key]
        end

        keys.grep(/\A#{Regexp.escape(key)}\(\d+[if]?\)\z/) do |k|
          if permitted_scalar?(self[k])
            params[k] = self[k]
          end
        end
      end

      def array_of_permitted_scalars?(value)
        if value.is_a?(Array)
          value.all? {|element| permitted_scalar?(element)}
        end
      end

      def array_of_permitted_scalars_filter(params, key)
        if has_key?(key) && array_of_permitted_scalars?(self[key])
          params[key] = self[key]
        end
      end

      EMPTY_ARRAY = []
      def hash_filter(params, filter)
        filter = filter.with_indifferent_access

        slice(*filter.keys).each do |key, value|
          next unless value

          if filter[key] == EMPTY_ARRAY
            array_of_permitted_scalars_filter(params, key)
          else
            params[key] = each_element(value) do |element|
              if element.is_a?(Hash)
                element = self.class.new(element) unless element.respond_to?(:permit)
                element.permit(*Array.wrap(filter[key]))
              end
            end
          end
        end
      end
  end

  module StrongParameters
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    def params
      @_params ||= Parameters.new(request.parameters)
    end

    def params=(value)
      @_params = value.is_a?(Hash) ? Parameters.new(value) : value
    end
  end
end
