require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  DISALLOWED_TEMPLATE_ARGS = [:to, :from, :base_url,
                              :user_preferences_url,
                              :include_respond_instructions, :html_override,
                              :add_unsubscribe_link, :respond_instructions,
                              :style, :body, :post_id, :topic_id, :subject,
                              :template, :allow_reply_by_email,
                              :private_reply, :from_alias]

  def send_rejection(template, message_from, template_args)
    if template_args.keys.any? { |k| DISALLOWED_TEMPLATE_ARGS.include? k }
      raise ArgumentError.new('Reserved key in template arguments')
    end

    build_email(message_from, template_args.merge(template: "system_messages.#{template}"))
  end

end
