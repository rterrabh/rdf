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
    module Sections
      def self.included(klass)
        constants.each do |name|
          #nodyna <const_get-1370> <CG COMPLEX (array)>
          section = RailsAdmin::Config::Sections.const_get(name)
          name = name.to_s.underscore.to_sym
          #nodyna <send-1371> <SD COMPLEX (private methods)>
          #nodyna <define_method-1372> <DM COMPLEX (events)>
          klass.send(:define_method, name) do |&block|
            @sections = {} unless @sections
            @sections[name] = section.new(self) unless @sections[name]
            #nodyna <instance_eval-1373> <IEV COMPLEX (block execution)>
            @sections[name].instance_eval(&block) if block
            @sections[name]
          end
        end
      end
    end
  end
end
