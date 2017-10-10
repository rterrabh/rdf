require File.expand_path('../boot', __FILE__)

<% if include_all_railties? -%>
require 'rails/all'
<% else -%>
require "rails"
require "active_model/railtie"
require "active_job/railtie"
<%= comment_if :skip_active_record %>require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
<%= comment_if :skip_sprockets %>require "sprockets/railtie"
<%= comment_if :skip_test_unit %>require "rails/test_unit/railtie"
<% end -%>

Bundler.require(*Rails.groups)

module <%= app_const_base %>
  class Application < Rails::Application


    <%- unless options.skip_active_record? -%>

    config.active_record.raise_in_transactional_callbacks = true
    <%- end -%>
  end
end
