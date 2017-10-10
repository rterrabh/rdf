module RailsAdmin
  module Config
    module Fields
      mattr_reader :default_factory
      @@default_factory = proc do |parent, properties, fields|
        if properties.association?
          association = parent.abstract_model.associations.detect { |a| a.name.to_s == properties.name.to_s }
          field = RailsAdmin::Config::Fields::Types.load("#{association.polymorphic? ? :polymorphic : properties.type}_association").new(parent, properties.name, association)
        else
          field = RailsAdmin::Config::Fields::Types.load(properties.type).new(parent, properties.name, properties)
        end
        fields << field
        field
      end

      @@registry = [@@default_factory]

      def self.factory(parent)
        fields = []

        parent.abstract_model.properties.each do |properties|
          next if fields.detect { |f| f.name == properties.name }
          @@registry.detect { |factory| factory.call(parent, properties, fields) }
        end
        parent.abstract_model.associations.select { |a| a.type != :belongs_to }.each do |association| # :belongs_to are created by factory for belongs_to fields
          next if fields.detect { |f| f.name == association.name }
          @@registry.detect { |factory| factory.call(parent, association, fields) }
        end
        fields
      end

      def self.register_factory(&block)
        @@registry.unshift(block)
      end
    end
  end
end

require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/factories/password'
require 'rails_admin/config/fields/factories/enum'
require 'rails_admin/config/fields/factories/devise'
require 'rails_admin/config/fields/factories/paperclip'
require 'rails_admin/config/fields/factories/dragonfly'
require 'rails_admin/config/fields/factories/carrierwave'
require 'rails_admin/config/fields/factories/association'
