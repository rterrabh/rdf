module Vagrant
  module Config
    module V1
      class DummyConfig
        def method_missing(name, *args, &block)
          DummyConfig.new
        end
      end
    end
  end
end
