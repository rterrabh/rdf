module ActionDispatch
  class TestResponse < Response
    def self.from_response(response)
      new response.status, response.headers, response.body, default_headers: nil
    end

    alias_method :success?, :successful?

    alias_method :missing?, :not_found?

    alias_method :redirect?, :redirection?

    alias_method :error?, :server_error?
  end
end
