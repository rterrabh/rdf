module Capybara
  module Node
    module Matchers

      def has_selector?(*args)
        assert_selector(*args)
      rescue Capybara::ExpectationNotMet
        return false
      end

      def has_no_selector?(*args)
        assert_no_selector(*args)
      rescue Capybara::ExpectationNotMet
        return false
      end

      def assert_selector(*args)
        query = Capybara::Query.new(*args)
        synchronize(query.wait) do
          result = query.resolve_for(self)
          matches_count = Capybara::Helpers.matches_count?(result.size, query.options)
          unless matches_count && ((result.size > 0) || Capybara::Helpers.expects_none?(query.options))
            raise Capybara::ExpectationNotMet, result.failure_message
          end
        end
        return true
      end

      def assert_no_selector(*args)
        query = Capybara::Query.new(*args)
        synchronize(query.wait) do
          result = query.resolve_for(self)
          matches_count = Capybara::Helpers.matches_count?(result.size, query.options)
          if matches_count && ((result.size > 0) || Capybara::Helpers.expects_none?(query.options))
            raise Capybara::ExpectationNotMet, result.negative_failure_message
          end
        end
        return true
      end
      alias_method :refute_selector, :assert_no_selector

      def has_xpath?(path, options={})
        has_selector?(:xpath, path, options)
      end

      def has_no_xpath?(path, options={})
        has_no_selector?(:xpath, path, options)
      end

      def has_css?(path, options={})
        has_selector?(:css, path, options)
      end

      def has_no_css?(path, options={})
        has_no_selector?(:css, path, options)
      end

      def has_link?(locator, options={})
        has_selector?(:link, locator, options)
      end

      def has_no_link?(locator, options={})
        has_no_selector?(:link, locator, options)
      end

      def has_button?(locator, options={})
        has_selector?(:button, locator, options)
      end

      def has_no_button?(locator, options={})
        has_no_selector?(:button, locator, options)
      end

      def has_field?(locator, options={})
        has_selector?(:field, locator, options)
      end

      def has_no_field?(locator, options={})
        has_no_selector?(:field, locator, options)
      end

      def has_checked_field?(locator, options={})
        has_selector?(:field, locator, options.merge(:checked => true))
      end

      def has_no_checked_field?(locator, options={})
        has_no_selector?(:field, locator, options.merge(:checked => true))
      end

      def has_unchecked_field?(locator, options={})
        has_selector?(:field, locator, options.merge(:unchecked => true))
      end

      def has_no_unchecked_field?(locator, options={})
        has_no_selector?(:field, locator, options.merge(:unchecked => true))
      end

      def has_select?(locator, options={})
        has_selector?(:select, locator, options)
      end

      def has_no_select?(locator, options={})
        has_no_selector?(:select, locator, options)
      end

      def has_table?(locator, options={})
        has_selector?(:table, locator, options)
      end

      def has_no_table?(locator, options={})
        has_no_selector?(:table, locator, options)
      end

      def assert_text(*args)
        query = Capybara::Queries::TextQuery.new(*args)
        synchronize(query.wait) do
          count = query.resolve_for(self)
          matches_count = Capybara::Helpers.matches_count?(count, query.options)
          unless matches_count && ((count > 0) || Capybara::Helpers.expects_none?(query.options))
            raise Capybara::ExpectationNotMet, query.failure_message
          end
        end
        return true
      end

      def assert_no_text(*args)
        query = Capybara::Queries::TextQuery.new(*args)
        synchronize(query.wait) do
          count = query.resolve_for(self)
          matches_count = Capybara::Helpers.matches_count?(count, query.options)
          if matches_count && ((count > 0) || Capybara::Helpers.expects_none?(query.options))
            raise Capybara::ExpectationNotMet, query.negative_failure_message
          end
        end
        return true
      end

      def has_text?(*args)
        assert_text(*args)
      rescue Capybara::ExpectationNotMet
        return false
      end
      alias_method :has_content?, :has_text?

      def has_no_text?(*args)
        assert_no_text(*args)
      rescue Capybara::ExpectationNotMet
        return false
      end
      alias_method :has_no_content?, :has_no_text?

      def ==(other)
        self.eql?(other) || (other.respond_to?(:base) && base == other.base)
      end
    end
  end
end
