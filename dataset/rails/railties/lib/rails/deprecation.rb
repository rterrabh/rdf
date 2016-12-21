require 'active_support/deprecation/proxy_wrappers'

module Rails
  class DeprecatedConstant < ActiveSupport::Deprecation::DeprecatedConstantProxy
    def self.deprecate(old, current)
      # double assignment is used to avoid "assigned but unused variable" warning
      constant = constant = new(old, current)
      #nodyna <ID:eval-5> <eval VERY HIGH ex6>
      eval "::#{old} = constant"
    end

    private

    def target
      #nodyna <ID:eval-6> <eval VERY HIGH ex2>
      ::Kernel.eval @new_const.to_s
    end
  end

  DeprecatedConstant.deprecate('RAILS_CACHE', '::Rails.cache')
end
