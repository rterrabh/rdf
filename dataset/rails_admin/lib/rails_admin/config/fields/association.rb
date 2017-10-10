require 'rails_admin/config'
require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      class Association < RailsAdmin::Config::Fields::Base
        def self.inherited(klass)
          super(klass)
        end

        def association # rubocop:disable TrivialAccessors
          @properties
        end

        register_instance_option :pretty_value do
          v = bindings[:view]
          [value].flatten.select(&:present?).collect do |associated|
            amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
            am = amc.abstract_model
            #nodyna <send-1368> <SD COMPLEX (change-prone variables)>
            wording = associated.send(amc.object_label_method)
            can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
            can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : ERB::Util.html_escape(wording)
          end.to_sentence.html_safe
        end

        register_instance_option :visible? do
          @visible ||= !associated_model_config.excluded?
        end

        register_instance_option :label do
          (@label ||= {})[::I18n.locale] ||= abstract_model.model.human_attribute_name association.name
        end

        register_instance_option :associated_collection_scope do
          associated_collection_scope_limit = (associated_collection_cache_all ? nil : 30)
          proc do |scope|
            scope.limit(associated_collection_scope_limit)
          end
        end

        register_instance_option :inverse_of do
          association.inverse_of
        end

        register_instance_option :associated_collection_cache_all do
          @associated_collection_cache_all ||= (associated_model_config.abstract_model.count < 100)
        end

        def associated_model_config
          @associated_model_config ||= RailsAdmin.config(association.klass)
        end

        def associated_object_label_method
          @associated_object_label_method ||= associated_model_config.object_label_method
        end

        def associated_primary_key
          @associated_primary_key ||= association.primary_key
        end

        def foreign_key
          association.foreign_key
        end

        def polymorphic?
          association.polymorphic?
        end

        register_instance_option :nested_form do
          association.nested_options
        end

        def value
          #nodyna <send-1369> <SD COMPLEX (change-prone variables)>
          bindings[:object].send(association.name)
        end

        def multiple?
          true
        end

        def virtual?
          true
        end
      end
    end
  end
end
