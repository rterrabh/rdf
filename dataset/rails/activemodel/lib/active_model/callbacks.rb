require 'active_support/core_ext/array/extract_options'

module ActiveModel
  module Callbacks
    def self.extended(base) #:nodoc:
      #nodyna <class_eval-940> <CE TRIVIAL (block execution)>
      base.class_eval do
        include ActiveSupport::Callbacks
      end
    end

    def define_model_callbacks(*callbacks)
      options = callbacks.extract_options!
      options = {
        terminator: ->(_,result) { result == false },
        skip_after_callbacks_if_terminated: true,
        scope: [:kind, :name],
        only: [:before, :around, :after]
      }.merge!(options)

      types = Array(options.delete(:only))

      callbacks.each do |callback|
        define_callbacks(callback, options)

        types.each do |type|
          #nodyna <send-941> <SD MODERATE (array)>
          send("_define_#{type}_model_callback", self, callback)
        end
      end
    end

    private

    def _define_before_model_callback(klass, callback) #:nodoc:
      klass.define_singleton_method("before_#{callback}") do |*args, &block|
        set_callback(:"#{callback}", :before, *args, &block)
      end
    end

    def _define_around_model_callback(klass, callback) #:nodoc:
      klass.define_singleton_method("around_#{callback}") do |*args, &block|
        set_callback(:"#{callback}", :around, *args, &block)
      end
    end

    def _define_after_model_callback(klass, callback) #:nodoc:
      klass.define_singleton_method("after_#{callback}") do |*args, &block|
        options = args.extract_options!
        options[:prepend] = true
        conditional = ActiveSupport::Callbacks::Conditionals::Value.new { |v|
          v != false
        }
        options[:if] = Array(options[:if]) << conditional
        set_callback(:"#{callback}", :after, *(args << options), &block)
      end
    end
  end
end
