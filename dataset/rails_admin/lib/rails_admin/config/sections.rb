require 'active_support/core_ext/string/inflections'
require 'rails_admin/config/sections/base'
require 'rails_admin/config/sections/edit'
require 'rails_admin/config/sections/update'
require 'rails_admin/config/sections/create'
require 'rails_admin/config/sections/nested'
require 'rails_admin/config/sections/modal'
require 'rails_admin/config/sections/list'
require 'rails_admin/config/sections/export'
require 'rails_admin/config/sections/show'

module RailsAdmin
  module Config
    # Sections describe different views in the RailsAdmin engine. Configurable sections are
    # list and navigation.
    #
    # Each section's class object can store generic configuration about that section (such as the
    # number of visible tabs in the main navigation), while the instances (accessed via model
    # configuration objects) store model specific configuration (such as the visibility of the
    # model).
    module Sections
      def self.included(klass)
        # Register accessors for all the sections in this namespace
        constants.each do |name|
          #nodyna <ID:const_get-1> <const_get VERY HIGH ex2>
          section = RailsAdmin::Config::Sections.const_get(name)
          name = name.to_s.underscore.to_sym
          #nodyna <ID:send-35> <send VERY HIGH ex4>
          #nodyna <ID:define_method-1> <define_method VERY HIGH ex2>
          klass.send(:define_method, name) do |&block|
            @sections = {} unless @sections
            @sections[name] = section.new(self) unless @sections[name]
            #nodyna <ID:instance_eval-11> <instance_eval VERY HIGH ex3>
            @sections[name].instance_eval(&block) if block
            @sections[name]
          end
        end
      end
    end
  end
end