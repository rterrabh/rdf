module Vagrant
  module Action
    class Hook
      attr_reader :before_hooks

      attr_reader :after_hooks

      attr_reader :prepend_hooks

      attr_reader :append_hooks

      def initialize
        @before_hooks  = Hash.new { |h, k| h[k] = [] }
        @after_hooks   = Hash.new { |h, k| h[k] = [] }
        @prepend_hooks = []
        @append_hooks  = []
      end

      def before(existing, new, *args, &block)
        @before_hooks[existing] << [new, args, block]
      end

      def after(existing, new, *args, &block)
        @after_hooks[existing] << [new, args, block]
      end

      def append(new, *args, &block)
        @append_hooks << [new, args, block]
      end

      def prepend(new, *args, &block)
        @prepend_hooks << [new, args, block]
      end

      def apply(builder, options=nil)
        options ||= {}

        if !options[:no_prepend_or_append]
          @prepend_hooks.each do |klass, args, block|
            builder.insert(0, klass, *args, &block)
          end

          @append_hooks.each do |klass, args, block|
            builder.use(klass, *args, &block)
          end
        end

        @before_hooks.each do |key, list|
          next if !builder.index(key)

          list.each do |klass, args, block|
            builder.insert_before(key, klass, *args, &block)
          end
        end

        @after_hooks.each do |key, list|
          next if !builder.index(key)

          list.each do |klass, args, block|
            builder.insert_after(key, klass, *args, &block)
          end
        end
      end
    end
  end
end
