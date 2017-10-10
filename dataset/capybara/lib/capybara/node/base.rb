module Capybara
  module Node

    class Base
      attr_reader :session, :base, :parent

      include Capybara::Node::Finders
      include Capybara::Node::Actions
      include Capybara::Node::Matchers

      def initialize(session, base)
        @session = session
        @base = base
      end

      def reload
        self
      end

      def synchronize(seconds=Capybara.default_max_wait_time, options = {})
        start_time = Capybara::Helpers.monotonic_time

        if session.synchronized
          yield
        else
          session.synchronized = true
          begin
            yield
          rescue => e
            session.raise_server_error!
            raise e unless driver.wait?
            raise e unless catch_error?(e, options[:errors])
            raise e if (Capybara::Helpers.monotonic_time - start_time) >= seconds
            sleep(0.05)
            raise Capybara::FrozenInTime, "time appears to be frozen, Capybara does not work with libraries which freeze time, consider using time travelling instead" if Capybara::Helpers.monotonic_time == start_time
            reload if Capybara.automatic_reload
            retry
          ensure
            session.synchronized = false
          end
        end
      end

      def find_css(css)
        base.find_css(css)
      end

      def find_xpath(xpath)
        base.find_xpath(xpath)
      end

    protected

      def catch_error?(error, errors = nil)
        errors ||= (driver.invalid_element_errors + [Capybara::ElementNotFound])
        errors.any? do |type|
          error.is_a?(type)
        end
      end

      def driver
        session.driver
      end
    end
  end
end
