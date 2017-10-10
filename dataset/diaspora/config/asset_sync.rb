if AppConfig.environment.assets.upload? && AppConfig.environment.s3.enable?
  require 'pathname'
  module Rails
    def self.root
      @@root ||= Pathname.new(__FILE__).dirname.join('..')
    end
  end

  require 'asset_sync'
end
