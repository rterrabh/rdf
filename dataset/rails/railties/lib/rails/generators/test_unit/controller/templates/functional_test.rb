require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>ControllerTest < ActionController::TestCase
<% if mountable_engine? -%>
  setup do
    @routes = Engine.routes
  end

<% end -%>
<% if actions.empty? -%>
<% else -%>
<% actions.each do |action| -%>
  test "should get <%= action %>" do
    get :<%= action %>
    assert_response :success
  end

<% end -%>
<% end -%>
end
<% end -%>
