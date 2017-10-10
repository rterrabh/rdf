require 'active_support/concern'

module Grape
  module DSL
    module Validations
      extend ActiveSupport::Concern

      include Grape::DSL::Configuration

      module ClassMethods
        def reset_validations!
          unset_namespace_stackable :declared_params
          unset_namespace_stackable :validations
          unset_namespace_stackable :params
          unset_description_field :params
        end

        def params(&block)
          Grape::Validations::ParamsScope.new(api: self, type: Hash, &block)
        end

        def document_attribute(names, opts)
          setting = description_field(:params)
          setting ||= description_field(:params, {})
          Array(names).each do |name|
            setting[name[:full_name].to_s] ||= {}
            setting[name[:full_name].to_s].merge!(opts)

            namespace_stackable(:params, name[:full_name].to_s => opts)
          end
        end
      end
    end
  end
end
