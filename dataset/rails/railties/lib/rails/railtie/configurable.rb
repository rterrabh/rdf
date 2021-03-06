require 'active_support/concern'

module Rails
  class Railtie
    module Configurable
      extend ActiveSupport::Concern

      module ClassMethods
        delegate :config, to: :instance

        def inherited(base)
          raise "You cannot inherit from a #{self.superclass.name} child"
        end

        def instance
          @instance ||= new
        end

        def respond_to?(*args)
          super || instance.respond_to?(*args)
        end

        def configure(&block)
          #nodyna <class_eval-1148> <CE COMPLEX (block execution)>
          class_eval(&block)
        end

        protected

        def method_missing(*args, &block)
          #nodyna <send-1149> <SD COMPLEX (change-prone variables)>
          instance.send(*args, &block)
        end
      end
    end
  end
end
