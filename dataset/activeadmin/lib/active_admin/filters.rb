require 'active_admin/filters/dsl'
require 'active_admin/filters/resource_extension'
require 'active_admin/filters/formtastic_addons'
require 'active_admin/filters/forms'

# Add our Extensions
#nodyna <ID:send-10> <SD TRIVIAL (public methods)>
ActiveAdmin::ResourceDSL.send :include, ActiveAdmin::Filters::DSL
#nodyna <ID:send-11> <SD TRIVIAL (public methods)>
ActiveAdmin::Resource.send    :include, ActiveAdmin::Filters::ResourceExtension
#nodyna <ID:send-12> <SD TRIVIAL (public methods)>
ActiveAdmin::ViewHelpers.send :include, ActiveAdmin::Filters::ViewHelper
