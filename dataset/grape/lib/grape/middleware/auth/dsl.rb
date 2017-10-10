require 'rack/auth/basic'
require 'active_support/concern'

module Grape
  module Middleware
    module Auth
      module DSL
        extend ActiveSupport::Concern

        module ClassMethods
          def auth(type = nil, options = {}, &block)
            if type
              namespace_inheritable(:auth, { type: type.to_sym, proc: block }.merge(options))
              use Grape::Middleware::Auth::Base, namespace_inheritable(:auth)
            else
              namespace_inheritable(:auth)
            end
          end

          def http_basic(options = {}, &block)
            options[:realm] ||= 'API Authorization'
            auth :http_basic, options, &block
          end

          def http_digest(options = {}, &block)
            options[:realm] ||= 'API Authorization'
            options[:opaque] ||= 'secret'
            auth :http_digest, options, &block
          end
        end
      end
    end
  end
end
