module Spree
  class PaymentMethod::Check < PaymentMethod
    def actions
      %w{capture void}
    end

    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    def can_void?(payment)
      payment.state != 'void'
    end

    def capture(*args)
      simulated_successful_billing_response
    end

    def cancel(response); end

    def void(*args)
      simulated_successful_billing_response
    end

    def source_required?
      false
    end

    def credit(*args)
      simulated_successful_billing_response
    end

    private

    def simulated_successful_billing_response
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end
  end
end
