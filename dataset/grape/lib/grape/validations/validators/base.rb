module Grape
  module Validations
    class Base
      attr_reader :attrs

      def initialize(attrs, options, required, scope)
        @attrs = Array(attrs)
        @option = options
        @required = required
        @scope = scope
      end

      def validate!(params)
        attributes = AttributesIterator.new(self, @scope, params)
        attributes.each do |resource_params, attr_name|
          if @required || (resource_params.respond_to?(:key?) && resource_params.key?(attr_name))
            validate_param!(attr_name, resource_params)
          end
        end
      end

      def self.convert_to_short_name(klass)
        ret = klass.name.gsub(/::/, '/')
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .tr('-', '_')
              .downcase
        File.basename(ret, '_validator')
      end

      def self.inherited(klass)
        short_name = convert_to_short_name(klass)
        Validations.register_validator(short_name, klass)
      end
    end
  end
end
