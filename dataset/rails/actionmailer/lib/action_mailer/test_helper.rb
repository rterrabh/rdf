module ActionMailer
  module TestHelper
    def assert_emails(number)
      if block_given?
        original_count = ActionMailer::Base.deliveries.size
        yield
        new_count = ActionMailer::Base.deliveries.size
        assert_equal number, new_count - original_count, "#{number} emails expected, but #{new_count - original_count} were sent"
      else
        assert_equal number, ActionMailer::Base.deliveries.size
      end
    end

    def assert_no_emails(&block)
      assert_emails 0, &block
    end
  end
end
