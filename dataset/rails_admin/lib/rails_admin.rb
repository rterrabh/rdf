require 'rails_admin/engine'
require 'rails_admin/abstract_model'
require 'rails_admin/config'
require 'rails_admin/extension'
require 'rails_admin/extensions/cancan'
require 'rails_admin/extensions/cancancan'
require 'rails_admin/extensions/paper_trail'
require 'rails_admin/extensions/history'
require 'rails_admin/support/csv_converter'
require 'rails_admin/support/core_extensions'

module RailsAdmin
  def self.config(entity = nil, &block)
    if entity
      RailsAdmin::Config.model(entity, &block)
    elsif block_given?
      block.call(RailsAdmin::Config)
    else
      RailsAdmin::Config
    end
  end
end

require 'rails_admin/bootstrap-sass' unless defined? Bootstrap
