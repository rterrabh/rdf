ActiveAdmin.before_load do |app|
  require "active_admin/batch_actions/resource_extension"
  require "active_admin/batch_actions/controller"

  #nodyna <send-40> <SD TRIVIAL (public methods)>
  ActiveAdmin::Resource.send :include, ActiveAdmin::BatchActions::ResourceExtension
  #nodyna <send-41> <SD TRIVIAL (public methods)>
  ActiveAdmin::ResourceController.send :include, ActiveAdmin::BatchActions::Controller

  require "active_admin/batch_actions/views/batch_action_form"
  require "active_admin/batch_actions/views/batch_action_popover"
  require "active_admin/batch_actions/views/selection_cells"
  require "active_admin/batch_actions/views/batch_action_selector"

  app.view_factory.register batch_action_selector: ActiveAdmin::BatchActions::BatchActionSelector
end
