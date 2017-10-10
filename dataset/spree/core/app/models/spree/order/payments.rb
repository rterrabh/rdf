module Spree
  class Order < Spree::Base
    module Payments
      extend ActiveSupport::Concern
      included do
        def process_payments!
          process_payments_with(:process!)
        end

        def authorize_payments!
          process_payments_with(:authorize!)
        end

        def capture_payments!
          process_payments_with(:purchase!)
        end

        def pending_payments
          payments.select { |payment| payment.pending? }
        end

        def unprocessed_payments
          payments.select { |payment| payment.checkout? }
        end

        private

        def process_payments_with(method)
          return if payment_total >= total
          raise Core::GatewayError.new(Spree.t(:no_payment_found)) if unprocessed_payments.empty?

          unprocessed_payments.each do |payment|
            break if payment_total >= total

            #nodyna <send-2505> <SD MODERATE (change-prone variables)>
            payment.public_send(method)

            if payment.completed?
              self.payment_total += payment.amount
            end
          end
        rescue Core::GatewayError => e
          result = !!Spree::Config[:allow_checkout_on_gateway_error]
          errors.add(:base, e.message) and return result
        end
      end
    end
  end
end
