require 'rails/app_rails_loader'

Rails::AppRailsLoader.exec_app_rails

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit(1) }

if ARGV.first == 'plugin'
  ARGV.shift
  require 'rails/commands/plugin'
else
  require 'rails/commands/application'
end
