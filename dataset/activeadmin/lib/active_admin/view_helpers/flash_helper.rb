module ActiveAdmin
  module ViewHelpers
    module FlashHelper

      def flash_messages
        @flash_messages ||= flash.to_hash.with_indifferent_access.except(*active_admin_application.flash_keys_to_except)
      end

    end
  end
end
