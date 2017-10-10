require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  module Rescuable
    extend Concern

    included do
      class_attribute :rescue_handlers
      self.rescue_handlers = []
    end

    module ClassMethods
      def rescue_from(*klasses, &block)
        options = klasses.extract_options!

        unless options.has_key?(:with)
          if block_given?
            options[:with] = block
          else
            raise ArgumentError, "Need a handler. Supply an options hash that has a :with key as the last argument."
          end
        end

        klasses.each do |klass|
          key = if klass.is_a?(Class) && klass <= Exception
            klass.name
          elsif klass.is_a?(String)
            klass
          else
            raise ArgumentError, "#{klass} is neither an Exception nor a String"
          end

          self.rescue_handlers += [[key, options[:with]]]
        end
      end
    end

    def rescue_with_handler(exception)
      if handler = handler_for_rescue(exception)
        handler.arity != 0 ? handler.call(exception) : handler.call
        true # don't rely on the return value of the handler
      end
    end

    def handler_for_rescue(exception)
      _, rescuer = self.class.rescue_handlers.reverse.detect do |klass_name, handler|
        #nodyna <const_get-1031> <CG COMPLEX (change-prone variable)>
        klass = self.class.const_get(klass_name) rescue nil
        klass ||= klass_name.constantize rescue nil
        exception.is_a?(klass) if klass
      end

      case rescuer
      when Symbol
        method(rescuer)
      when Proc
        if rescuer.arity == 0
          #nodyna <instance_exec-1032> <IEX COMPLEX (block without parameters)>
          Proc.new { instance_exec(&rescuer) }
        else
          #nodyna <instance_exec-1033> <IEX COMPLEX (block with parameters)>
          Proc.new { |_exception| instance_exec(_exception, &rescuer) }
        end
      end
    end
  end
end
