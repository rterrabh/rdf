module Capybara
  module Node
    module DocumentMatchers
      def assert_title(title, options = {})
        query = Capybara::Queries::TitleQuery.new(title, options)
        synchronize(query.wait) do
          unless query.resolves_for?(self)
            raise Capybara::ExpectationNotMet, query.failure_message
          end
        end
        return true
      end

      def assert_no_title(title, options = {})
        query = Capybara::Queries::TitleQuery.new(title, options)
        synchronize(query.wait) do
          if query.resolves_for?(self)
            raise Capybara::ExpectationNotMet, query.negative_failure_message
          end
        end
        return true
      end

      def has_title?(title, options = {})
        assert_title(title, options)
      rescue Capybara::ExpectationNotMet
        return false
      end

      def has_no_title?(title, options = {})
        assert_no_title(title, options)
      rescue Capybara::ExpectationNotMet
        return false
      end
    end
  end
end
