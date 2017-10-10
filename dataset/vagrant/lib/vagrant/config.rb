require "vagrant/registry"

module Vagrant
  module Config
    autoload :Loader,        'vagrant/config/loader'
    autoload :VersionBase,   'vagrant/config/version_base'

    autoload :V1,            'vagrant/config/v1'
    autoload :V2,            'vagrant/config/v2'

    CONFIGURE_MUTEX = Mutex.new

    VERSIONS = Registry.new
    VERSIONS.register("1") { V1::Loader }
    VERSIONS.register("2") { V2::Loader }

    VERSIONS_ORDER = ["1", "2"]
    CURRENT_VERSION = VERSIONS_ORDER.last

    def self.run(version="1", &block)
      @last_procs ||= []
      @last_procs << [version.to_s, block]
    end

    def self.capture_configures
      CONFIGURE_MUTEX.synchronize do
        @last_procs = []

        yield

        return @last_procs
      end
    end
  end
end
