module CanCan

  module ModelAdditions
    module ClassMethods
      def accessible_by(ability, action = :index)
        ability.model_adapter(self, action).database_records
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end
