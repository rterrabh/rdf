module SimpleForm
  module ActionViewExtensions
    module Builder

      def simple_fields_for(*args, &block)
        options = args.extract_options!
        options[:wrapper] = self.options[:wrapper] if options[:wrapper].nil?
        options[:defaults] ||= self.options[:defaults]

        if self.class < ActionView::Helpers::FormBuilder
          options[:builder] ||= self.class
        else
          options[:builder] ||= SimpleForm::FormBuilder
        end
        fields_for(*args, options, &block)
      end
    end
  end
end

module ActionView::Helpers
  class FormBuilder
    include SimpleForm::ActionViewExtensions::Builder
  end
end
