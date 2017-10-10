require 'rails_admin/config/fields/group'

module RailsAdmin
  module Config
    module HasGroups
      def group(name, &block)
        group = parent.groups.detect { |g| name == g.name }
        group ||= (parent.groups << RailsAdmin::Config::Fields::Group.new(self, name)).last
        #nodyna <instance_eval-1420> <IEV COMPLEX (block execution)>
        group.tap { |g| g.section = self }.instance_eval(&block) if block
        group
      end

      def visible_groups
        parent.groups.collect { |f| f.section = self; f.with(bindings) }.select(&:visible?).select do |g| # rubocop:disable Semicolon
          g.visible_fields.present?
        end
      end
    end
  end
end
