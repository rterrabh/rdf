require 'active_support/core_ext/object/blank'

module ActiveSupport
  module Testing
    module Assertions
      def assert_not(object, message = nil)
        message ||= "Expected #{mu_pp(object)} to be nil or false"
        assert !object, message
      end

      def assert_difference(expression, difference = 1, message = nil, &block)
        expressions = Array(expression)

        exps = expressions.map { |e|
          #nodyna <eval-1132> <EV COMPLEX (change-prone variables)>
          e.respond_to?(:call) ? e : lambda { eval(e, block.binding) }
        }
        before = exps.map { |e| e.call }

        yield

        expressions.zip(exps).each_with_index do |(code, e), i|
          error  = "#{code.inspect} didn't change by #{difference}"
          error  = "#{message}.\n#{error}" if message
          assert_equal(before[i] + difference, e.call, error)
        end
      end

      def assert_no_difference(expression, message = nil, &block)
        assert_difference expression, 0, message, &block
      end
    end
  end
end
