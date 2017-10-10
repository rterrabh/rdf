module ActiveAdmin
  module ViewHelpers
    module IconHelper

      def icon(*args)
        ActiveAdmin::Iconic.icon(*args)
      end

    end
  end
end
