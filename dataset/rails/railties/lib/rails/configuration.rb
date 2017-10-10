require 'active_support/ordered_options'
require 'active_support/core_ext/object'
require 'rails/paths'
require 'rails/rack'

module Rails
  module Configuration
    class MiddlewareStackProxy
      def initialize
        @operations = []
      end

      def insert_before(*args, &block)
        @operations << [__method__, args, block]
      end

      alias :insert :insert_before

      def insert_after(*args, &block)
        @operations << [__method__, args, block]
      end

      def swap(*args, &block)
        @operations << [__method__, args, block]
      end

      def use(*args, &block)
        @operations << [__method__, args, block]
      end

      def delete(*args, &block)
        @operations << [__method__, args, block]
      end

      def unshift(*args, &block)
        @operations << [__method__, args, block]
      end

      def merge_into(other) #:nodoc:
        @operations.each do |operation, args, block|
          #nodyna <send-1143> <SD MODERATE (array)>
          other.send(operation, *args, &block)
        end
        other
      end
    end

    class Generators #:nodoc:
      attr_accessor :aliases, :options, :templates, :fallbacks, :colorize_logging
      attr_reader :hidden_namespaces

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @fallbacks = {}
        @templates = []
        @colorize_logging = true
        @hidden_namespaces = []
      end

      def initialize_copy(source)
        @aliases = @aliases.deep_dup
        @options = @options.deep_dup
        @fallbacks = @fallbacks.deep_dup
        @templates = @templates.dup
      end

      def hide_namespace(namespace)
        @hidden_namespaces << namespace
      end

      def method_missing(method, *args)
        method = method.to_s.sub(/=$/, '').to_sym

        return @options[method] if args.empty?

        if method == :rails || args.first.is_a?(Hash)
          namespace, configuration = method, args.shift
        else
          namespace, configuration = args.shift, args.shift
          namespace = namespace.to_sym if namespace.respond_to?(:to_sym)
          @options[:rails][method] = namespace
        end

        if configuration
          aliases = configuration.delete(:aliases)
          @aliases[namespace].merge!(aliases) if aliases
          @options[namespace].merge!(configuration)
        end
      end
    end
  end
end
