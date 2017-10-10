module Vagrant
  module Action
    class Builder
      attr_reader :stack

      def self.build(middleware, *args, &block)
        new.use(middleware, *args, &block)
      end

      def initialize
        @stack = []
      end

      def initialize_copy(original)
        super

        @stack = original.stack.dup
      end

      def flatten
        lambda do |env|
          self.call(env)
        end
      end

      def use(middleware, *args, &block)
        if middleware.kind_of?(Builder)
          self.stack.concat(middleware.stack)
        else
          self.stack << [middleware, args, block]
        end

        self
      end

      def insert(index, middleware, *args, &block)
        index = self.index(index) unless index.is_a?(Integer)
        raise "no such middleware to insert before: #{index.inspect}" unless index

        if middleware.kind_of?(Builder)
          middleware.stack.reverse.each do |stack_item|
            stack.insert(index, stack_item)
          end
        else
          stack.insert(index, [middleware, args, block])
        end
      end

      alias_method :insert_before, :insert

      def insert_after(index, middleware, *args, &block)
        index = self.index(index) unless index.is_a?(Integer)
        raise "no such middleware to insert after: #{index.inspect}" unless index
        insert(index + 1, middleware, *args, &block)
      end

      def replace(index, middleware, *args, &block)
        if index.is_a?(Integer)
          delete(index)
          insert(index, middleware, *args, &block)
        else
          insert_before(index, middleware, *args, &block)
          delete(index)
        end
      end

      def delete(index)
        index = self.index(index) unless index.is_a?(Integer)
        stack.delete_at(index)
      end

      def call(env)
        to_app(env).call(env)
      end

      def index(object)
        stack.each_with_index do |item, i|
          return i if item[0] == object
          return i if item[0].respond_to?(:name) && item[0].name == object
        end

        nil
      end

      def to_app(env)
        app_stack = nil

        if env[:action_hooks]
          builder = self.dup

          options = {}

          if env[:action_hooks_already_ran]
            options[:no_prepend_or_append] = true
          end

          env[:action_hooks_already_ran] = true

          env[:action_hooks].each do |hook|
            hook.apply(builder, options)
          end

          app_stack = builder.stack.dup
        end

        app_stack ||= stack.dup

        Warden.new(app_stack, env)
      end
    end
  end
end
