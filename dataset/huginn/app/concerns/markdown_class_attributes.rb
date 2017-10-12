module MarkdownClassAttributes
  extend ActiveSupport::Concern

  module ClassMethods
    def markdown_class_attributes(*attributes)
      attributes.each do |attribute|
        #nodyna <class_eval-2943> <CE MODERATE (define methods)>
        class_eval <<-RUBY
          def html_#{attribute}
            Kramdown::Document.new(#{attribute}, :auto_ids => false).to_html.html_safe
          end

          def #{attribute}
            if self.class.#{attribute}.is_a?(Proc)
              #nodyna <instance_eval-2944> <IEV MODERATE (block execution)>
              Utils.unindent(self.instance_eval(&self.class.#{attribute}) || "No #{attribute} has been set.")
            else
              Utils.unindent(self.class.#{attribute} || "No #{attribute} has been set.")
            end
          end

          def self.#{attribute}(value = nil, &block)
            if block
              @#{attribute} = block
            elsif value
              @#{attribute} = value
            end
            @#{attribute}
          end
        RUBY
      end
    end
  end
end
