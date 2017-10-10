
require 'active_support'
require 'active_support/rails'
require 'active_model/version'

module ActiveModel
  extend ActiveSupport::Autoload

  autoload :AttributeMethods
  autoload :BlockValidator, 'active_model/validator'
  autoload :Callbacks
  autoload :Conversion
  autoload :Dirty
  autoload :EachValidator, 'active_model/validator'
  autoload :ForbiddenAttributesProtection
  autoload :Lint
  autoload :Model
  autoload :Name, 'active_model/naming'
  autoload :Naming
  autoload :SecurePassword
  autoload :Serialization
  autoload :TestCase
  autoload :Translation
  autoload :Validations
  autoload :Validator

  eager_autoload do
    autoload :Errors
    autoload :StrictValidationFailed, 'active_model/errors'
  end

  module Serializers
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :JSON
      autoload :Xml
    end
  end

  def self.eager_load!
    super
    ActiveModel::Serializers.eager_load!
  end
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.dirname(__FILE__) + '/active_model/locale/en.yml'
end
