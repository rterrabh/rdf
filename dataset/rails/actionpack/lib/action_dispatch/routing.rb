require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/regexp'
require 'active_support/dependencies/autoload'

module ActionDispatch
  module Routing
    extend ActiveSupport::Autoload

    autoload :Mapper
    autoload :RouteSet
    autoload :RoutesProxy
    autoload :UrlFor
    autoload :PolymorphicRoutes

    SEPARATORS = %w( / . ? ) #:nodoc:
    HTTP_METHODS = [:get, :head, :post, :patch, :put, :delete, :options] #:nodoc:
  end
end
