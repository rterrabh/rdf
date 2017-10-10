module SimpleForm
  module Wrappers
    class Builder
      def initialize(options)
        @options    = options
        @components = []
      end

      def use(name, options = {})
        if options && wrapper = options[:wrap_with]
          @components << Single.new(name, wrapper, options.except(:wrap_with))
        else
          @components << Leaf.new(name, options)
        end
      end

      def optional(name, options = {}, &block)
        @options[name] = false
        use(name, options)
      end

      def wrapper(name, options = nil)
        if block_given?
          name, options = nil, name if name.is_a?(Hash)
          builder = self.class.new(@options)
          options ||= {}
          options[:tag] = :div if options[:tag].nil?
          yield builder
          @components << Many.new(name, builder.to_a, options)
        else
          raise ArgumentError, "A block is required as argument to wrapper"
        end
      end

      def to_a
        @components
      end
    end
  end
end
