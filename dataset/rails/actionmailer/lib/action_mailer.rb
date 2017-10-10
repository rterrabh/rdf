
require 'abstract_controller'
require 'action_mailer/version'

require 'active_support/rails'
require 'active_support/core_ext/class'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/string/inflections'
require 'active_support/lazy_load_hooks'

module ActionMailer
  extend ::ActiveSupport::Autoload

  eager_autoload do
    autoload :Collector
  end

  autoload :Base
  autoload :DeliveryMethods
  autoload :InlinePreviewInterceptor
  autoload :MailHelper
  autoload :Preview
  autoload :Previews, 'action_mailer/preview'
  autoload :TestCase
  autoload :TestHelper
  autoload :MessageDelivery
  autoload :DeliveryJob
end
