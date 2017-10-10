require 'i18n'
require 'active_support/core_ext/array/extract_options'
require 'spree/i18n/base'

module Spree
  extend ActionView::Helpers::TranslationHelper
  extend ActionView::Helpers::TagHelper

  class << self
    def translate(*args)
      @virtual_path = virtual_path

      options = args.extract_options!
      options[:scope] = [*options[:scope]].unshift(:spree)
      args << options
      super(*args)
    end

    alias_method :t, :translate

    def context
      Spree::ViewContext.context
    end

    def virtual_path
      if context
        #nodyna <instance_variable_get-2560> <not yet classified>
        path = context.instance_variable_get("@virtual_path")

        if path
          path.gsub(/spree/, '')
        end
      end
    end
  end
end
