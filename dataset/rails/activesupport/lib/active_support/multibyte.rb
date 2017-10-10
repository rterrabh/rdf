module ActiveSupport #:nodoc:
  module Multibyte
    autoload :Chars, 'active_support/multibyte/chars'
    autoload :Unicode, 'active_support/multibyte/unicode'

    def self.proxy_class=(klass)
      @proxy_class = klass
    end

    def self.proxy_class
      @proxy_class ||= ActiveSupport::Multibyte::Chars
    end
  end
end
