module Pod
  module Generator
    module XCConfig
      autoload :AggregateXCConfig,  'cocoapods/generator/xcconfig/aggregate_xcconfig'
      autoload :PodXCConfig,        'cocoapods/generator/xcconfig/pod_xcconfig'
      autoload :XCConfigHelper,     'cocoapods/generator/xcconfig/xcconfig_helper'
    end
  end
end
