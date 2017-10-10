require 'action_view/helpers/tag_helper'
require 'active_support/core_ext/string/access'
require 'i18n/exceptions'

module ActionView
  module Helpers
    module TranslationHelper
      include TagHelper
      def translate(key, options = {})
        options = options.dup
        has_default = options.has_key?(:default)
        remaining_defaults = Array(options.delete(:default)).compact

        if has_default && !remaining_defaults.first.kind_of?(Symbol)
          options[:default] = remaining_defaults
        end

        if options[:raise] == false || (options.key?(:rescue_format) && options[:rescue_format].nil?)
          raise_error = false
          i18n_raise = false
        else
          raise_error = options[:raise] || options[:rescue_format] || ActionView::Base.raise_on_missing_translations
          i18n_raise = true
        end

        if html_safe_translation_key?(key)
          html_safe_options = options.dup
          options.except(*I18n::RESERVED_KEYS).each do |name, value|
            unless name == :count && value.is_a?(Numeric)
              html_safe_options[name] = ERB::Util.html_escape(value.to_s)
            end
          end
          translation = I18n.translate(scope_key_by_partial(key), html_safe_options.merge(raise: i18n_raise))

          translation.respond_to?(:html_safe) ? translation.html_safe : translation
        else
          I18n.translate(scope_key_by_partial(key), options.merge(raise: i18n_raise))
        end
      rescue I18n::MissingTranslationData => e
        if remaining_defaults.present?
          translate remaining_defaults.shift, options.merge(default: remaining_defaults)
        else
          raise e if raise_error

          keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
          content_tag('span', keys.last.to_s.titleize, :class => 'translation_missing', :title => "translation missing: #{keys.join('.')}")
        end
      end
      alias :t :translate

      def localize(*args)
        I18n.localize(*args)
      end
      alias :l :localize

      private
        def scope_key_by_partial(key)
          if key.to_s.first == "."
            if @virtual_path
              @virtual_path.gsub(%r{/_?}, ".") + key.to_s
            else
              raise "Cannot use t(#{key.inspect}) shortcut because path is not available"
            end
          else
            key
          end
        end

        def html_safe_translation_key?(key)
          key.to_s =~ /(\b|_|\.)html$/
        end
    end
  end
end
