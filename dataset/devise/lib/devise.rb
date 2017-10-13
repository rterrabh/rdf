require 'rails'
require 'active_support/core_ext/numeric/time'
require 'active_support/dependencies'
require 'orm_adapter'
require 'set'
require 'securerandom'
require 'responders'

module Devise
  autoload :Delegator,          'devise/delegator'
  autoload :FailureApp,         'devise/failure_app'
  autoload :OmniAuth,           'devise/omniauth'
  autoload :ParameterFilter,    'devise/parameter_filter'
  autoload :BaseSanitizer,      'devise/parameter_sanitizer'
  autoload :ParameterSanitizer, 'devise/parameter_sanitizer'
  autoload :TestHelpers,        'devise/test_helpers'
  autoload :TimeInflector,      'devise/time_inflector'
  autoload :TokenGenerator,     'devise/token_generator'

  module Controllers
    autoload :Helpers, 'devise/controllers/helpers'
    autoload :Rememberable, 'devise/controllers/rememberable'
    autoload :ScopedViews, 'devise/controllers/scoped_views'
    autoload :SignInOut, 'devise/controllers/sign_in_out'
    autoload :StoreLocation, 'devise/controllers/store_location'
    autoload :UrlHelpers, 'devise/controllers/url_helpers'
  end

  module Hooks
    autoload :Proxy, 'devise/hooks/proxy'
  end

  module Mailers
    autoload :Helpers, 'devise/mailers/helpers'
  end

  module Strategies
    autoload :Base, 'devise/strategies/base'
    autoload :Authenticatable, 'devise/strategies/authenticatable'
  end

  ALL         = []
  CONTROLLERS = ActiveSupport::OrderedHash.new
  ROUTES      = ActiveSupport::OrderedHash.new
  STRATEGIES  = ActiveSupport::OrderedHash.new
  URL_HELPERS = ActiveSupport::OrderedHash.new

  NO_INPUT = []

  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE']

  mattr_accessor :secret_key
  @@secret_key = nil

  [ :allow_insecure_token_lookup,
    :allow_insecure_sign_in_after_confirmation,
    :token_authentication_key ].each do |method|
    #nodyna <class_eval-2740> <CE MODERATE (define methods)>
    class_eval <<-RUBY
    def self.#{method}
      ActiveSupport::Deprecation.warn "Devise.#{method} is deprecated " \
        "and has no effect"
    end

    def self.#{method}=(val)
      ActiveSupport::Deprecation.warn "Devise.#{method}= is deprecated " \
        "and has no effect"
    end
    RUBY
  end

  mattr_accessor :rememberable_options
  @@rememberable_options = {}

  mattr_accessor :stretches
  @@stretches = 10

  mattr_accessor :http_authentication_key
  @@http_authentication_key = nil

  mattr_accessor :authentication_keys
  @@authentication_keys = [ :email ]

  mattr_accessor :request_keys
  @@request_keys = []

  mattr_accessor :case_insensitive_keys
  @@case_insensitive_keys = [ :email ]

  mattr_accessor :strip_whitespace_keys
  @@strip_whitespace_keys = []

  mattr_accessor :http_authenticatable
  @@http_authenticatable = false

  mattr_accessor :http_authenticatable_on_xhr
  @@http_authenticatable_on_xhr = true

  mattr_accessor :params_authenticatable
  @@params_authenticatable = true

  mattr_accessor :http_authentication_realm
  @@http_authentication_realm = "Application"

  mattr_accessor :email_regexp
  @@email_regexp = /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/

  mattr_accessor :password_length
  @@password_length = 6..128

  mattr_accessor :remember_for
  @@remember_for = 2.weeks

  mattr_accessor :extend_remember_period
  @@extend_remember_period = false

  mattr_accessor :expire_all_remember_me_on_sign_out
  @@expire_all_remember_me_on_sign_out = true

  mattr_accessor :allow_unconfirmed_access_for
  @@allow_unconfirmed_access_for = 0.days

  mattr_accessor :confirm_within
  @@confirm_within = nil

  mattr_accessor :confirmation_keys
  @@confirmation_keys = [ :email ]

  mattr_accessor :reconfirmable
  @@reconfirmable = false

  mattr_accessor :timeout_in
  @@timeout_in = 30.minutes

  mattr_accessor :expire_auth_token_on_timeout
  @@expire_auth_token_on_timeout = false

  mattr_accessor :pepper
  @@pepper = nil

  mattr_accessor :scoped_views
  @@scoped_views = false

  mattr_accessor :lock_strategy
  @@lock_strategy = :failed_attempts

  mattr_accessor :unlock_keys
  @@unlock_keys = [ :email ]

  mattr_accessor :unlock_strategy
  @@unlock_strategy = :both

  mattr_accessor :maximum_attempts
  @@maximum_attempts = 20

  mattr_accessor :unlock_in
  @@unlock_in = 1.hour

  mattr_accessor :reset_password_keys
  @@reset_password_keys = [ :email ]

  mattr_accessor :reset_password_within
  @@reset_password_within = 6.hours

  mattr_accessor :default_scope
  @@default_scope = nil

  mattr_accessor :mailer_sender
  @@mailer_sender = nil

  mattr_accessor :skip_session_storage
  @@skip_session_storage = []

  mattr_accessor :navigational_formats
  @@navigational_formats = ["*/*", :html]

  mattr_accessor :sign_out_all_scopes
  @@sign_out_all_scopes = true

  mattr_accessor :sign_out_via
  @@sign_out_via = :get

  mattr_accessor :parent_controller
  @@parent_controller = "ApplicationController"

  mattr_accessor :parent_mailer
  @@parent_mailer = "ActionMailer::Base"

  mattr_accessor :router_name
  @@router_name = nil

  mattr_accessor :omniauth_path_prefix
  @@omniauth_path_prefix = nil

  mattr_accessor :clean_up_csrf_token_on_authentication
  @@clean_up_csrf_token_on_authentication = true


  mattr_reader :mappings
  @@mappings = ActiveSupport::OrderedHash.new

  mattr_reader :omniauth_configs
  @@omniauth_configs = ActiveSupport::OrderedHash.new

  mattr_reader :helpers
  @@helpers = Set.new
  @@helpers << Devise::Controllers::Helpers

  mattr_accessor :warden_config
  @@warden_config = nil
  @@warden_config_blocks = []

  mattr_accessor :paranoid
  @@paranoid = false

  mattr_accessor :last_attempt_warning
  @@last_attempt_warning = true

  mattr_accessor :token_generator
  @@token_generator = nil

  def self.setup
    yield self
  end

  class Getter
    def initialize name
      @name = name
    end

    def get
      ActiveSupport::Dependencies.constantize(@name)
    end
  end

  def self.ref(arg)
    if defined?(ActiveSupport::Dependencies::ClassCache)
      ActiveSupport::Dependencies::reference(arg)
      Getter.new(arg)
    else
      ActiveSupport::Dependencies.ref(arg)
    end
  end

  def self.available_router_name
    router_name || :main_app
  end

  def self.omniauth_providers
    omniauth_configs.keys
  end

  def self.mailer
    @@mailer_ref.get
  end

  def self.mailer=(class_name)
    @@mailer_ref = ref(class_name)
  end
  self.mailer = "Devise::Mailer"

  def self.add_mapping(resource, options)
    mapping = Devise::Mapping.new(resource, options)
    @@mappings[mapping.name] = mapping
    @@default_scope ||= mapping.name
    @@helpers.each { |h| h.define_helpers(mapping) }
    mapping
  end

  def self.add_module(module_name, options = {})
    ALL << module_name
    options.assert_valid_keys(:strategy, :model, :controller, :route, :no_input)

    if strategy = options[:strategy]
      strategy = (strategy == true ? module_name : strategy)
      STRATEGIES[module_name] = strategy
    end

    if controller = options[:controller]
      controller = (controller == true ? module_name : controller)
      CONTROLLERS[module_name] = controller
    end

    NO_INPUT << strategy if options[:no_input]

    if route = options[:route]
      case route
      when TrueClass
        key, value = module_name, []
      when Symbol
        key, value = route, []
      when Hash
        key, value = route.keys.first, route.values.flatten
      else
        raise ArgumentError, ":route should be true, a Symbol or a Hash"
      end

      URL_HELPERS[key] ||= []
      URL_HELPERS[key].concat(value)
      URL_HELPERS[key].uniq!

      ROUTES[module_name] = key
    end

    if options[:model]
      path = (options[:model] == true ? "devise/models/#{module_name}" : options[:model])
      camelized = ActiveSupport::Inflector.camelize(module_name.to_s)
      #nodyna <send-2741> <SD TRIVIAL (public methods)>
      Devise::Models.send(:autoload, camelized.to_sym, path)
    end

    Devise::Mapping.add_module module_name
  end

  def self.warden(&block)
    @@warden_config_blocks << block
  end

  def self.omniauth(provider, *args)
    @@helpers << Devise::OmniAuth::UrlHelpers
    config = Devise::OmniAuth::Config.new(provider, args)
    @@omniauth_configs[config.strategy_name.to_sym] = config
  end

  def self.include_helpers(scope)
    ActiveSupport.on_load(:action_controller) do
      include scope::Helpers if defined?(scope::Helpers)
      include scope::UrlHelpers
    end

    ActiveSupport.on_load(:action_view) do
      include scope::UrlHelpers
    end
  end

  def self.regenerate_helpers!
    Devise::Controllers::UrlHelpers.remove_helpers!
    Devise::Controllers::UrlHelpers.generate_helpers!
  end

  def self.configure_warden! #:nodoc:
    @@warden_configured ||= begin
      warden_config.failure_app   = Devise::Delegator.new
      warden_config.default_scope = Devise.default_scope
      warden_config.intercept_401 = false

      Devise.mappings.each_value do |mapping|
        warden_config.scope_defaults mapping.name, strategies: mapping.strategies

        warden_config.serialize_into_session(mapping.name) do |record|
          mapping.to.serialize_into_session(record)
        end

        warden_config.serialize_from_session(mapping.name) do |key|
          args = key[-2, 2]
          mapping.to.serialize_from_session(*args)
        end
      end

      @@warden_config_blocks.map { |block| block.call Devise.warden_config }
      true
    end
  end

  def self.friendly_token
    SecureRandom.urlsafe_base64(15).tr('lIO0', 'sxyz')
  end

  def self.secure_compare(a, b)
    return false if a.blank? || b.blank? || a.bytesize != b.bytesize
    l = a.unpack "C#{a.bytesize}"

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end
end

require 'warden'
require 'devise/mapping'
require 'devise/models'
require 'devise/modules'
require 'devise/rails'
