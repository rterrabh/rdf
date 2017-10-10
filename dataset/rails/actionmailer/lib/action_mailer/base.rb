require 'mail'
require 'action_mailer/collector'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/anonymous'

require 'action_mailer/log_subscriber'

module ActionMailer
  class Base < AbstractController::Base
    include DeliveryMethods
    include Previews

    abstract!

    include AbstractController::Rendering

    include AbstractController::Logger
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::AssetPaths
    include AbstractController::Callbacks

    include ActionView::Layouts

    PROTECTED_IVARS = AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES + [:@_action_has_layout]

    def _protected_ivars # :nodoc:
      PROTECTED_IVARS
    end

    helper ActionMailer::MailHelper

    private_class_method :new #:nodoc:

    class_attribute :default_params
    self.default_params = {
      mime_version: "1.0",
      charset:      "UTF-8",
      content_type: "text/plain",
      parts_order:  [ "text/plain", "text/enriched", "text/html" ]
    }.freeze

    class << self
      def register_observers(*observers)
        observers.flatten.compact.each { |observer| register_observer(observer) }
      end

      def register_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| register_interceptor(interceptor) }
      end

      def register_observer(observer)
        delivery_observer = case observer
          when String, Symbol
            observer.to_s.camelize.constantize
          else
            observer
          end

        Mail.register_observer(delivery_observer)
      end

      def register_interceptor(interceptor)
        delivery_interceptor = case interceptor
          when String, Symbol
            interceptor.to_s.camelize.constantize
          else
            interceptor
          end

        Mail.register_interceptor(delivery_interceptor)
      end

      def mailer_name
        @mailer_name ||= anonymous? ? "anonymous" : name.underscore
      end
      attr_writer :mailer_name
      alias :controller_path :mailer_name

      def default(value = nil)
        self.default_params = default_params.merge(value).freeze if value
        default_params
      end
      alias :default_options= :default

      def receive(raw_mail)
        ActiveSupport::Notifications.instrument("receive.action_mailer") do |payload|
          mail = Mail.new(raw_mail)
          set_payload_for_mail(payload, mail)
          new.receive(mail)
        end
      end

      def deliver_mail(mail) #:nodoc:
        ActiveSupport::Notifications.instrument("deliver.action_mailer") do |payload|
          set_payload_for_mail(payload, mail)
          yield # Let Mail do the delivery actions
        end
      end

      def respond_to?(method, include_private = false) #:nodoc:
        super || action_methods.include?(method.to_s)
      end

    protected

      def set_payload_for_mail(payload, mail) #:nodoc:
        payload[:mailer]     = name
        payload[:message_id] = mail.message_id
        payload[:subject]    = mail.subject
        payload[:to]         = mail.to
        payload[:from]       = mail.from
        payload[:bcc]        = mail.bcc if mail.bcc.present?
        payload[:cc]         = mail.cc  if mail.cc.present?
        payload[:date]       = mail.date
        payload[:mail]       = mail.encoded
      end

      def method_missing(method_name, *args) # :nodoc:
        if action_methods.include?(method_name.to_s)
          MessageDelivery.new(self, method_name, *args)
        else
          super
        end
      end
    end

    attr_internal :message

    def initialize(method_name=nil, *args)
      super()
      @_mail_was_called = false
      @_message = Mail.new
      process(method_name, *args) if method_name
    end

    def process(method_name, *args) #:nodoc:
      payload = {
        mailer: self.class.name,
        action: method_name
      }

      ActiveSupport::Notifications.instrument("process.action_mailer", payload) do
        lookup_context.skip_default_locale!

        super
        @_message = NullMail.new unless @_mail_was_called
      end
    end

    class NullMail #:nodoc:
      def body; '' end
      def header; {} end

      def respond_to?(string, include_all=false)
        true
      end

      def method_missing(*args)
        nil
      end
    end

    def mailer_name
      self.class.mailer_name
    end

    def headers(args = nil)
      if args
        @_message.headers(args)
      else
        @_message
      end
    end

    def attachments
      if @_mail_was_called
        LateAttachmentsProxy.new(@_message.attachments)
      else
        @_message.attachments
      end
    end

    class LateAttachmentsProxy < SimpleDelegator
      def inline; _raise_error end
      def []=(_name, _content); _raise_error end

      private
        def _raise_error
          raise RuntimeError, "Can't add attachments after `mail` was called.\n" \
                              "Make sure to use `attachments[]=` before calling `mail`."
        end
    end

    def mail(headers = {}, &block)
      return @_message if @_mail_was_called && headers.blank? && !block

      m = @_message

      content_type = headers[:content_type]

      default_values = {}
      self.class.default.each do |k,v|
        #nodyna <instance_eval-1185> <IEV COMPLEX (block execution)>
        default_values[k] = v.is_a?(Proc) ? instance_eval(&v) : v
      end

      headers = headers.reverse_merge(default_values)
      headers[:subject] ||= default_i18n_subject

      m.charset = charset = headers[:charset]

      wrap_delivery_behavior!(headers.delete(:delivery_method), headers.delete(:delivery_method_options))

      assignable = headers.except(:parts_order, :content_type, :body, :template_name, :template_path)
      assignable.each { |k, v| m[k] = v }

      responses = collect_responses(headers, &block)
      @_mail_was_called = true

      create_parts_from_responses(m, responses)

      m.content_type = set_content_type(m, content_type, headers[:content_type])
      m.charset      = charset

      if m.multipart?
        m.body.set_sort_order(headers[:parts_order])
        m.body.sort_parts!
      end

      m
    end

  protected

    def set_content_type(m, user_content_type, class_default)
      params = m.content_type_parameters || {}
      case
      when user_content_type.present?
        user_content_type
      when m.has_attachments?
        if m.attachments.detect { |a| a.inline? }
          ["multipart", "related", params]
        else
          ["multipart", "mixed", params]
        end
      when m.multipart?
        ["multipart", "alternative", params]
      else
        m.content_type || class_default
      end
    end

    def default_i18n_subject(interpolations = {})
      mailer_scope = self.class.mailer_name.tr('/', '.')
      I18n.t(:subject, interpolations.merge(scope: [mailer_scope, action_name], default: action_name.humanize))
    end

    def collect_responses(headers) #:nodoc:
      responses = []

      if block_given?
        collector = ActionMailer::Collector.new(lookup_context) { render(action_name) }
        yield(collector)
        responses = collector.responses
      elsif headers[:body]
        responses << {
          body: headers.delete(:body),
          content_type: self.class.default[:content_type] || "text/plain"
        }
      else
        templates_path = headers.delete(:template_path) || self.class.mailer_name
        templates_name = headers.delete(:template_name) || action_name

        each_template(Array(templates_path), templates_name) do |template|
          self.formats = template.formats

          responses << {
            body: render(template: template),
            content_type: template.type.to_s
          }
        end
      end

      responses
    end

    def each_template(paths, name, &block) #:nodoc:
      templates = lookup_context.find_all(name, paths)
      if templates.empty?
        raise ActionView::MissingTemplate.new(paths, name, paths, false, 'mailer')
      else
        templates.uniq { |t| t.formats }.each(&block)
      end
    end

    def create_parts_from_responses(m, responses) #:nodoc:
      if responses.size == 1 && !m.has_attachments?
        responses[0].each { |k,v| m[k] = v }
      elsif responses.size > 1 && m.has_attachments?
        container = Mail::Part.new
        container.content_type = "multipart/alternative"
        responses.each { |r| insert_part(container, r, m.charset) }
        m.add_part(container)
      else
        responses.each { |r| insert_part(m, r, m.charset) }
      end
    end

    def insert_part(container, response, charset) #:nodoc:
      response[:charset] ||= charset
      part = Mail::Part.new(response)
      container.add_part(part)
    end

    def self.supports_path?
      false
    end

    ActiveSupport.run_load_hooks(:action_mailer, self)
  end
end
