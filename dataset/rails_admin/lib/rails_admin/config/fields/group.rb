require 'active_support/core_ext/string/inflections'
require 'rails_admin/config/proxyable'
require 'rails_admin/config/configurable'
require 'rails_admin/config/hideable'

module RailsAdmin
  module Config
    module Fields
      class Group
        include RailsAdmin::Config::Proxyable
        include RailsAdmin::Config::Configurable
        include RailsAdmin::Config::Hideable

        attr_reader :name, :abstract_model
        attr_accessor :section
        attr_reader :parent, :root

        def initialize(parent, name)
          @parent = parent
          @root = parent.root

          @abstract_model = parent.abstract_model
          @section = parent
          @name = name.to_s.tr(' ', '_').downcase.to_sym
        end

        def field(name, type = nil, &block)
          field = section.field(name, type, &block)
          #nodyna <instance_variable_set-1363> <not yet classified>
          field.instance_variable_set('@group', self)
          field
        end

        def fields
          section.fields.select { |f| f.group == self }
        end

        def fields_of_type(type, &block)
          selected = section.fields.select { |f| type == f.type }
          #nodyna <instance_eval-1364> <IEV COMPLEX (block execution)>
          selected.each { |f| f.instance_eval(&block) } if block
          selected
        end

        def visible_fields
          section.with(bindings).visible_fields.select { |f| f.group == self }
        end

        register_instance_option :active? do
          true
        end

        register_instance_option :label do
          (@label ||= {})[::I18n.locale] ||= (parent.fields.detect { |f| f.name == name }.try(:label) || name.to_s.humanize)
        end

        register_instance_option :help do
          nil
        end
      end
    end
  end
end
