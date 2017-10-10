module Capybara
  module Node

    class Document < Base
      include Capybara::Node::DocumentMatchers

      def inspect
        %(#<Capybara::Document>)
      end

      def text(type=nil)
        find(:xpath, '/html').text(type)
      end

      def title
        session.driver.title
      end
    end
  end
end
