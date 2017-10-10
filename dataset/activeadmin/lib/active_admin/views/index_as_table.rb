module ActiveAdmin
  module Views

    class IndexAsTable < ActiveAdmin::Component

      def build(page_presenter, collection)
        table_options = {
          id: "index_table_#{active_admin_config.resource_name.plural}",
          sortable: true,
          class: "index_table index",
          i18n: active_admin_config.resource_class,
          paginator: page_presenter[:paginator] != false,
          row_class: page_presenter[:row_class]
        }

        table_for collection, table_options do |t|
          table_config_block = page_presenter.block || default_table
          #nodyna <instance_exec-56> <IEX COMPLEX (block with parameters)>
          instance_exec(t, &table_config_block)
        end
      end

      def table_for(*args, &block)
        insert_tag IndexTableFor, *args, &block
      end

      def default_table
        proc do
          selectable_column
          id_column if resource_class.primary_key # View based Models have no primary_key
          resource_class.content_columns.each do |col|
            column col.name.to_sym
          end
          actions
        end
      end

      def self.index_name
        "table"
      end

      class IndexTableFor < ::ActiveAdmin::Views::TableFor

        def selectable_column
          return unless active_admin_config.batch_actions.any?
          column resource_selection_toggle_cell, class: 'col-selectable', sortable: false do |resource|
            resource_selection_cell resource
          end
        end

        def id_column
          raise "#{resource_class.name} as no primary_key!" unless resource_class.primary_key
          column(resource_class.human_attribute_name(resource_class.primary_key), sortable: resource_class.primary_key) do |resource|
            if controller.action_methods.include?('show')
              link_to resource.id, resource_path(resource), class: "resource_id_link"
            else
              resource.id
            end
          end
        end

        def default_actions
          raise '`default_actions` is no longer provided in ActiveAdmin 1.x. Use `actions` instead.'
        end

        def actions(options = {}, &block)
          name          = options.delete(:name)     { '' }
          defaults      = options.delete(:defaults) { true }
          dropdown      = options.delete(:dropdown) { false }
          dropdown_name = options.delete(:dropdown_name) { I18n.t 'active_admin.dropdown_actions.button_label', default: 'Actions' }

          options[:class] ||= 'col-actions'

          column name, options do |resource|
            if dropdown
              dropdown_menu dropdown_name do
                defaults(resource) if defaults
                #nodyna <instance_exec-57> <IEX COMPLEX (block with parameters)>
                instance_exec(resource, &block) if block_given?
              end
            else
              table_actions do
                defaults(resource, css_class: :member_link) if defaults
                if block_given?
                  #nodyna <instance_exec-58> <IEX COMPLEX (block with parameters)>
                  block_result = instance_exec(resource, &block)
                  text_node block_result unless block_result.is_a? Arbre::Element
                end
              end
            end
          end
        end

      private

        def defaults(resource, options = {})
          if controller.action_methods.include?('show') && authorized?(ActiveAdmin::Auth::READ, resource)
            item I18n.t('active_admin.view'), resource_path(resource), class: "view_link #{options[:css_class]}"
          end
          if controller.action_methods.include?('edit') && authorized?(ActiveAdmin::Auth::UPDATE, resource)
            item I18n.t('active_admin.edit'), edit_resource_path(resource), class: "edit_link #{options[:css_class]}"
          end
          if controller.action_methods.include?('destroy') && authorized?(ActiveAdmin::Auth::DESTROY, resource)
            item I18n.t('active_admin.delete'), resource_path(resource), class: "delete_link #{options[:css_class]}",
              method: :delete, data: {confirm: I18n.t('active_admin.delete_confirmation')}
          end
        end

        class TableActions < ActiveAdmin::Component
          builder_method :table_actions

          def item *args
            text_node link_to *args
          end
        end
      end # IndexTableFor

    end # IndexAsTable
  end
end
