require 'active_support/concern'

module Grape
  module DSL
    module Helpers
      extend ActiveSupport::Concern
      include Grape::DSL::Configuration

      module ClassMethods
        def helpers(new_mod = nil, &block)
          if block_given? || new_mod
            mod = new_mod || Module.new
            if new_mod
              inject_api_helpers_to_mod(new_mod) if new_mod.is_a?(BaseHelper)
            end
            if block_given?
              inject_api_helpers_to_mod(mod) do
                #nodyna <class_eval-2820> <CE COMPLEX (block execution)>
                mod.class_eval(&block)
              end
            end

            namespace_stackable(:helpers, mod)
          else
            mod = Module.new
            namespace_stackable(:helpers).each do |mod_to_include|
              #nodyna <send-2821> <SD TRIVIAL (public method)>
              mod.send :include, mod_to_include
            end
            change!
            mod
          end
        end

        protected

        def inject_api_helpers_to_mod(mod, &_block)
          mod.extend(BaseHelper)
          yield if block_given?
          mod.api_changed(self)
        end
      end

      module BaseHelper
        attr_accessor :api
        def params(name, &block)
          @named_params ||= {}
          @named_params[name] = block
        end

        def api_changed(new_api)
          @api = new_api
          process_named_params
        end

        protected

        def process_named_params
          if @named_params && @named_params.any?
            api.namespace_stackable(:named_params, @named_params)
          end
        end
      end
    end
  end
end
