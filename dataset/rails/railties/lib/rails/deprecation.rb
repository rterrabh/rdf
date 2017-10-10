require 'active_support/deprecation/proxy_wrappers'

module Rails
  class DeprecatedConstant < ActiveSupport::Deprecation::DeprecatedConstantProxy
    def self.deprecate(old, current)
      constant = constant = new(old, current)
      #nodyna <eval-1167> <EV COMPLEX (variable definition)>
      eval "::#{old} = constant"
    end

    private

    def target
      #nodyna <eval-1168> <EV COMPLEX (change-prone variables)>
      ::Kernel.eval @new_const.to_s
    end
  end

  DeprecatedConstant.deprecate('RAILS_CACHE', '::Rails.cache')
end
