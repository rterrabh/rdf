
module ActionDispatch
  module Assertions
    module ResponseAssertions
      def assert_response(type, message = nil)
        message ||= "Expected response to be a <#{type}>, but was <#{@response.response_code}>"

        if Symbol === type
          if [:success, :missing, :redirect, :error].include?(type)
            #nodyna <send-1291> <SD MODERATE (change-prone variables)>
            assert @response.send("#{type}?"), message
          else
            code = Rack::Utils::SYMBOL_TO_STATUS_CODE[type]
            if code.nil?
              raise ArgumentError, "Invalid response type :#{type}"
            end
            assert_equal code, @response.response_code, message
          end
        else
          assert_equal type, @response.response_code, message
        end
      end

      def assert_redirected_to(options = {}, message=nil)
        assert_response(:redirect, message)
        return true if options === @response.location

        redirect_is       = normalize_argument_to_redirection(@response.location)
        redirect_expected = normalize_argument_to_redirection(options)

        message ||= "Expected response to be a redirect to <#{redirect_expected}> but was a redirect to <#{redirect_is}>"
        assert_operator redirect_expected, :===, redirect_is, message
      end

      private
        def parameterize(value)
          value.respond_to?(:to_param) ? value.to_param : value
        end

        def normalize_argument_to_redirection(fragment)
          if Regexp === fragment
            fragment
          else
            handle = @controller || ActionController::Redirecting
            handle._compute_redirect_to_location(@request, fragment)
          end
        end
    end
  end
end
