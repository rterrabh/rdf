
module ErrorMessagesHelper
  def error_messages_for(*objects)
    options = objects.extract_options!
    options[:message] ||= I18n.t('error_messages.helper.correct_the_following_errors_and_try_again')
    messages = objects.compact.map { |o| o.errors.full_messages }.flatten
    unless messages.empty?
      content_tag(:div, class: "text-error") do
        list_items = messages.map { |msg| content_tag(:li, msg) }
        content_tag(:h2, options[:header_message]) + content_tag(:p, options[:message]) + content_tag(:ul, list_items.join.html_safe)
      end
    end
  end

  module FormBuilderAdditions
    def error_messages(options = {})
      @template.error_messages_for(@object, options)
    end
  end
end

#nodyna <send-232> <SD TRIVIAL (public methods)>
ActionView::Helpers::FormBuilder.send(:include, ErrorMessagesHelper::FormBuilderAdditions)
