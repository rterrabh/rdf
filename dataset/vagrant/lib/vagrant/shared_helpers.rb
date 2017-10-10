require "pathname"
require "tempfile"
require "thread"

module Vagrant
  @@global_lock = Mutex.new

  DEFAULT_SERVER_URL = "https://atlas.hashicorp.com"

  def self.global_lock
    @@global_lock.synchronize do
      return yield
    end
  end

  def self.in_installer?
    !!ENV["VAGRANT_INSTALLER_ENV"]
  end

  def self.installer_embedded_dir
    return nil if !Vagrant.in_installer?
    ENV["VAGRANT_INSTALLER_EMBEDDED_DIR"]
  end

  def self.plugins_enabled?
    !ENV["VAGRANT_NO_PLUGINS"] && $vagrant_bundler_runtime
  end

  def self.very_quiet?
    !!ENV["VAGRANT_I_KNOW_WHAT_IM_DOING_PLEASE_BE_QUIET"]
  end

  def self.log_level
    ENV["VAGRANT_LOG"]
  end

  def self.server_url(config_server_url=nil)
    result = ENV["VAGRANT_SERVER_URL"]
    result = config_server_url if result == "" or result == nil
    result || DEFAULT_SERVER_URL
  end

  def self.source_root
    @source_root ||= Pathname.new(File.expand_path('../../../', __FILE__))
  end

  def self.user_data_path
    path = ENV["VAGRANT_HOME"]

    if !path && ENV["USERPROFILE"]
      path = "#{ENV["USERPROFILE"]}/.vagrant.d"
    end

    path ||= "~/.vagrant.d"

    Pathname.new(path).expand_path
  end
end
