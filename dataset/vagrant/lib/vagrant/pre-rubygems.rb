
require_relative "shared_helpers"

if defined?(Bundler)
  require "bundler/shared_helpers"
  if Bundler::SharedHelpers.in_bundle? && !Vagrant.very_quiet?
    puts "Vagrant appears to be running in a Bundler environment. Your "
    puts "existing Gemfile will be used. Vagrant will not auto-load any plugins"
    puts "installed with `vagrant plugin`. Vagrant will autoload any plugins in"
    puts "the 'plugins' group in your Gemfile. You can force Vagrant to take over"
    puts "with VAGRANT_FORCE_BUNDLER."
    puts
  end
end

require_relative "bundler"
require_relative "plugin/manager"

plugins = Vagrant::Plugin::Manager.instance.installed_plugins
Vagrant::Bundler.instance.init!(plugins)

ENV["VAGRANT_INTERNAL_BUNDLERIZED"] = "1"

if ENV["VAGRANT_EXECUTABLE"]
  Kernel.exec("ruby", ENV["VAGRANT_EXECUTABLE"], *ARGV)
else
  Kernel.exec("vagrant", *ARGV)
end
