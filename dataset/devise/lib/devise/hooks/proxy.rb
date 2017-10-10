module Devise
  module Hooks
    class Proxy #:nodoc:
      include Devise::Controllers::Rememberable
      include Devise::Controllers::SignInOut

      attr_reader :warden
      delegate :cookies, :env, to: :warden

      def initialize(warden)
        @warden = warden
      end

      def session
        warden.request.session
      end
    end
  end
end
