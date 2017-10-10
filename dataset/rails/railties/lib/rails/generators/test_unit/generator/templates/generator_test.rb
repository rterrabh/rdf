require 'test_helper'
require '<%= generator_path %>'

<% module_namespacing do -%>
class <%= class_name %>GeneratorTest < Rails::Generators::TestCase
  tests <%= class_name %>Generator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

end
<% end -%>
