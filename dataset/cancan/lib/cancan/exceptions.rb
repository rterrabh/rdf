module CanCan
  class Error < StandardError; end

  class NotImplemented < Error; end

  class ImplementationRemoved < Error; end

  class AuthorizationNotPerformed < Error; end

  class AccessDenied < Error
    attr_reader :action, :subject
    attr_writer :default_message

    def initialize(message = nil, action = nil, subject = nil)
      @message = message
      @action = action
      @subject = subject
      @default_message = I18n.t(:"unauthorized.default", :default => "You are not authorized to access this page.")
    end

    def to_s
      @message || @default_message
    end
  end
end
