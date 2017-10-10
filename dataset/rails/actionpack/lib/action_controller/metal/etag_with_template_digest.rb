module ActionController
  module EtagWithTemplateDigest
    extend ActiveSupport::Concern

    include ActionController::ConditionalGet

    included do
      class_attribute :etag_with_template_digest
      self.etag_with_template_digest = true

      ActiveSupport.on_load :action_view, yield: true do |action_view_base|
        etag do |options|
          determine_template_etag(options) if etag_with_template_digest
        end
      end
    end

    private
    def determine_template_etag(options)
      if template = pick_template_for_etag(options)
        lookup_and_digest_template(template)
      end
    end

    def pick_template_for_etag(options)
      options.fetch(:template) { "#{controller_name}/#{action_name}" }
    end

    def lookup_and_digest_template(template)
      ActionView::Digestor.digest name: template, finder: lookup_context
    end
  end
end
