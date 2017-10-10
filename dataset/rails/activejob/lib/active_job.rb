
require 'active_support'
require 'active_support/rails'
require 'active_job/version'
require 'global_id'

module ActiveJob
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :QueueAdapters
  autoload :ConfiguredJob
  autoload :TestCase
  autoload :TestHelper
end
