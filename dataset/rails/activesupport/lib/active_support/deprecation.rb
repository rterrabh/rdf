require 'singleton'

module ActiveSupport
  class Deprecation
    require 'active_support/deprecation/instance_delegator'
    require 'active_support/deprecation/behaviors'
    require 'active_support/deprecation/reporting'
    require 'active_support/deprecation/method_wrappers'
    require 'active_support/deprecation/proxy_wrappers'
    require 'active_support/core_ext/module/deprecation'

    include Singleton
    include InstanceDelegator
    include Behavior
    include Reporting
    include MethodWrapper

    attr_accessor :deprecation_horizon

    def initialize(deprecation_horizon = '5.0', gem_name = 'Rails')
      self.gem_name = gem_name
      self.deprecation_horizon = deprecation_horizon
      self.silenced = false
      self.debug = false
    end
  end
end
