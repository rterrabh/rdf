require 'rails_admin/config/fields/group'

module RailsAdmin
  module Config
    module Groupable
      def group(name = nil)
        @group = parent.group(name) unless name.nil? # setter
        @group ||= parent.group(:default) # getter
      end
    end
  end
end
