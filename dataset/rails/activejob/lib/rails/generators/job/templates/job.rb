<% module_namespacing do -%>
class <%= class_name %>Job < ActiveJob::Base
  queue_as :<%= options[:queue] %>

  def perform(*args)
  end
end
<% end -%>
