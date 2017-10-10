module Spree
  module Admin
    module PaymentsHelper
      def payment_method_name(payment)
        id = payment.payment_method_id
        Spree::PaymentMethod.find_with_destroyed(id).name
      end
    end
  end
end
