
require 'securerandom'
require "active_support/dependencies/autoload"
require "active_support/version"
require "active_support/logger"
require "active_support/lazy_load_hooks"

module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :Concern
  autoload :Dependencies
  autoload :DescendantsTracker
  autoload :FileUpdateChecker
  autoload :LogSubscriber
  autoload :Notifications

  eager_autoload do
    autoload :BacktraceCleaner
    autoload :ProxyObject
    autoload :Benchmarkable
    autoload :Cache
    autoload :Callbacks
    autoload :Configurable
    autoload :Deprecation
    autoload :Gzip
    autoload :Inflector
    autoload :JSON
    autoload :KeyGenerator
    autoload :MessageEncryptor
    autoload :MessageVerifier
    autoload :Multibyte
    autoload :NumberHelper
    autoload :OptionMerger
    autoload :OrderedHash
    autoload :OrderedOptions
    autoload :StringInquirer
    autoload :TaggedLogging
    autoload :XmlMini
  end

  autoload :Rescuable
  autoload :SafeBuffer, "active_support/core_ext/string/output_safety"
  autoload :TestCase

  def self.eager_load!
    super

    NumberHelper.eager_load!
  end

  @@test_order = nil

  def self.test_order=(new_order) # :nodoc:
    @@test_order = new_order
  end

  def self.test_order # :nodoc:
    @@test_order
  end
end

autoload :I18n, "active_support/i18n"
