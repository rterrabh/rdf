require 'active_admin/filters/dsl'
require 'active_admin/filters/resource_extension'
require 'active_admin/filters/formtastic_addons'
require 'active_admin/filters/forms'

#nodyna <send-93> <SD TRIVIAL (public methods)>
ActiveAdmin::ResourceDSL.send :include, ActiveAdmin::Filters::DSL
#nodyna <send-94> <SD TRIVIAL (public methods)>
ActiveAdmin::Resource.send    :include, ActiveAdmin::Filters::ResourceExtension
#nodyna <send-95> <SD TRIVIAL (public methods)>
ActiveAdmin::ViewHelpers.send :include, ActiveAdmin::Filters::ViewHelper
