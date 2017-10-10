require 'html/pipeline/filter'
require 'html/pipeline/sanitization_filter'

module Gitlab
  module Markdown
    class SanitizationFilter < HTML::Pipeline::SanitizationFilter
      def whitelist
        if pipeline == :description
          whitelist = LIMITED
          whitelist[:elements] -= %w(pre code img ol ul li)
        else
          whitelist = super
        end

        customize_whitelist(whitelist)

        whitelist
      end

      private

      def pipeline
        context[:pipeline] || :default
      end

      def customized?(transformers)
        transformers.last.source_location[0] == __FILE__
      end

      def customize_whitelist(whitelist)
        return if customized?(whitelist[:transformers])

        whitelist[:attributes]['pre'] = %w(class)
        whitelist[:attributes]['span'] = %w(class)

        whitelist[:attributes]['th'] = %w(style)
        whitelist[:attributes]['td'] = %w(style)

        whitelist[:elements].push('span')

        whitelist[:transformers].push(remove_rel)

        whitelist[:transformers].push(clean_spans)

        whitelist
      end

      def remove_rel
        lambda do |env|
          if env[:node_name] == 'a'
            env[:node].remove_attribute('rel')
          end
        end
      end

      def clean_spans
        lambda do |env|
          return unless env[:node_name] == 'span'
          return unless env[:node].has_attribute?('class')

          unless has_ancestor?(env[:node], 'pre')
            env[:node].remove_attribute('class')
          end
        end
      end
    end
  end
end
