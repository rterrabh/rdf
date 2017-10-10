module Rake
  module InvocationExceptionMixin
    def chain
      @rake_invocation_chain ||= nil
    end

    def chain=(value)
      @rake_invocation_chain = value
    end
  end
end
