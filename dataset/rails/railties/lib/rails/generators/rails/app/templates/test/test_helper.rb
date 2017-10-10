ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
<% unless options[:skip_active_record] -%>
  fixtures :all

<% end -%>
end
