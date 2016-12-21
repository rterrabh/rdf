require 'active_admin/filters/dsl'
require 'active_admin/filters/resource_extension'
require 'active_admin/filters/formtastic_addons'
require 'active_admin/filters/forms'

# Add our Extensions
#nodyna <ID:send-10> <send VERY LOW ex1>
ActiveAdmin::ResourceDSL.send :include, ActiveAdmin::Filters::DSL
#nodyna <ID:send-11> <send VERY LOW ex1>
ActiveAdmin::Resource.send    :include, ActiveAdmin::Filters::ResourceExtension
#nodyna <ID:send-12> <send VERY LOW ex1>
ActiveAdmin::ViewHelpers.send :include, ActiveAdmin::Filters::ViewHelper
