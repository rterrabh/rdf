module ActiveRecord
  module DynamicMatchers #:nodoc:

    def respond_to?(name, include_private = false)
      if self == Base
        super
      else
        match = Method.match(self, name)
        match && match.valid? || super
      end
    end

    private

    def method_missing(name, *arguments, &block)
      match = Method.match(self, name)

      if match && match.valid?
        match.define
        #nodyna <send-860> <SD COMPLEX (change-prone variables)>
        send(name, *arguments, &block)
      else
        super
      end
    end

    class Method
      @matchers = []

      class << self
        attr_reader :matchers

        def match(model, name)
          klass = matchers.find { |k| name =~ k.pattern }
          klass.new(model, name) if klass
        end

        def pattern
          @pattern ||= /\A#{prefix}_([_a-zA-Z]\w*)#{suffix}\Z/
        end

        def prefix
          raise NotImplementedError
        end

        def suffix
          ''
        end
      end

      attr_reader :model, :name, :attribute_names

      def initialize(model, name)
        @model           = model
        @name            = name.to_s
        @attribute_names = @name.match(self.class.pattern)[1].split('_and_')
        @attribute_names.map! { |n| @model.attribute_aliases[n] || n }
      end

      def valid?
        attribute_names.all? { |name| model.columns_hash[name] || model.reflect_on_aggregation(name.to_sym) }
      end

      def define
        #nodyna <class_eval-861> <not yet classified>
        model.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def self.#{name}(#{signature})
          end
        CODE
      end

      def body
        raise NotImplementedError
      end
    end

    module Finder
      def body
        result
      end

      def result
        "#{finder}(#{attributes_hash})"
      end

      def signature
        attribute_names.map { |name| "_#{name}" }.join(', ')
      end

      def attributes_hash
        "{" + attribute_names.map { |name| ":#{name} => _#{name}" }.join(',') + "}"
      end

      def finder
        raise NotImplementedError
      end
    end

    class FindBy < Method
      Method.matchers << self
      include Finder

      def self.prefix
        "find_by"
      end

      def finder
        "find_by"
      end
    end

    class FindByBang < Method
      Method.matchers << self
      include Finder

      def self.prefix
        "find_by"
      end

      def self.suffix
        "!"
      end

      def finder
        "find_by!"
      end
    end
  end
end
