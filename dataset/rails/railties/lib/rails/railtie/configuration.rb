require 'rails/configuration'

module Rails
  class Railtie
    class Configuration
      def initialize
        @@options ||= {}
      end

      def self.eager_load_namespaces #:nodoc:
        @@eager_load_namespaces ||= []
      end

      def eager_load_namespaces
        @@eager_load_namespaces ||= []
      end

      def watchable_files
        @@watchable_files ||= []
      end

      def watchable_dirs
        @@watchable_dirs ||= {}
      end

      def app_middleware
        @@app_middleware ||= Rails::Configuration::MiddlewareStackProxy.new
      end

      def app_generators
        @@app_generators ||= Rails::Configuration::Generators.new
        yield(@@app_generators) if block_given?
        @@app_generators
      end

      def before_configuration(&block)
        ActiveSupport.on_load(:before_configuration, yield: true, &block)
      end

      def before_eager_load(&block)
        ActiveSupport.on_load(:before_eager_load, yield: true, &block)
      end

      def before_initialize(&block)
        ActiveSupport.on_load(:before_initialize, yield: true, &block)
      end

      def after_initialize(&block)
        ActiveSupport.on_load(:after_initialize, yield: true, &block)
      end

      def to_prepare_blocks
        @@to_prepare_blocks ||= []
      end

      def to_prepare(&blk)
        to_prepare_blocks << blk if blk
      end

      def respond_to?(name, include_private = false)
        super || @@options.key?(name.to_sym)
      end

    private

      def method_missing(name, *args, &blk)
        if name.to_s =~ /=$/
          @@options[$`.to_sym] = args.first
        elsif @@options.key?(name)
          @@options[name]
        else
          super
        end
      end
    end
  end
end
