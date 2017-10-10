
require 'active_support'
require 'active_support/rails'
require 'active_support/core_ext/module/attribute_accessors'

require 'action_pack'
require 'rack'

module Rack
  autoload :Test, 'rack/test'
end

module ActionDispatch
  extend ActiveSupport::Autoload

  class IllegalStateError < StandardError
  end

  eager_autoload do
    autoload_under 'http' do
      autoload :Request
      autoload :Response
    end
  end

  autoload_under 'middleware' do
    autoload :RequestId
    autoload :Callbacks
    autoload :Cookies
    autoload :DebugExceptions
    autoload :ExceptionWrapper
    autoload :Flash
    autoload :ParamsParser
    autoload :PublicExceptions
    autoload :Reloader
    autoload :RemoteIp
    autoload :ShowExceptions
    autoload :SSL
    autoload :Static
  end

  autoload :Journey
  autoload :MiddlewareStack, 'action_dispatch/middleware/stack'
  autoload :Routing

  module Http
    extend ActiveSupport::Autoload

    autoload :Cache
    autoload :Headers
    autoload :MimeNegotiation
    autoload :Parameters
    autoload :ParameterFilter
    autoload :Upload
    autoload :UploadedFile, 'action_dispatch/http/upload'
    autoload :URL
  end

  module Session
    autoload :AbstractStore,     'action_dispatch/middleware/session/abstract_store'
    autoload :CookieStore,       'action_dispatch/middleware/session/cookie_store'
    autoload :MemCacheStore,     'action_dispatch/middleware/session/mem_cache_store'
    autoload :CacheStore,        'action_dispatch/middleware/session/cache_store'
  end

  mattr_accessor :test_app

  autoload_under 'testing' do
    autoload :Assertions
    autoload :Integration
    autoload :IntegrationTest, 'action_dispatch/testing/integration'
    autoload :TestProcess
    autoload :TestRequest
    autoload :TestResponse
  end
end

autoload :Mime, 'action_dispatch/http/mime_type'

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template::Types.delegate_to Mime
end
