module Capybara
  module SessionMatchers
    def assert_current_path(path, options={})
      query = Capybara::Queries::CurrentPathQuery.new(path, options)
      document.synchronize(query.wait) do
        unless query.resolves_for?(self)
          raise Capybara::ExpectationNotMet, query.failure_message
        end
      end
      return true
    end

    def assert_no_current_path(path, options={})
      query = Capybara::Queries::CurrentPathQuery.new(path, options)
      document.synchronize(query.wait) do
        if query.resolves_for?(self)
          raise Capybara::ExpectationNotMet, query.negative_failure_message
        end
      end
      return true
    end

    def has_current_path?(path, options={})
      assert_current_path(path, options)
    rescue Capybara::ExpectationNotMet
      return false
    end

    def has_no_current_path?(path, options={})
      assert_no_current_path(path, options)
    rescue Capybara::ExpectationNotMet
      return false
    end
  end
end
