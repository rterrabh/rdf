<% module_namespacing do -%>
class <%= class_name %> < ApplicationMailer
<% actions.each do |action| -%>

  def <%= action %>
    @greeting = "Hi"

    mail to: "to@example.org"
  end
<% end -%>
end
<% end -%>
