ENV["RAILS_ENV"] = "test"

require File.expand_path("../../<%= options[:dummy_path] -%>/config/environment.rb",  __FILE__)
<% unless options[:skip_active_record] -%>
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../<%= options[:dummy_path] -%>/db/migrate", __FILE__)]
<% if options[:mountable] -%>
ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
<% end -%>
<% end -%>
require "rails/test_help"

Minitest.backtrace_filter = Minitest::BacktraceFilter.new

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.fixtures :all
end
