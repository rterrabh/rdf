require 'active_support/concern'

module Grape
  module DSL
    module Middleware
      extend ActiveSupport::Concern

      include Grape::DSL::Configuration

      module ClassMethods
        def use(middleware_class, *args, &block)
          arr = [middleware_class, *args]
          arr << block if block_given?

          namespace_stackable(:middleware, arr)
        end

        def middleware
          namespace_stackable(:middleware) || []
        end
      end
    end
  end
end
