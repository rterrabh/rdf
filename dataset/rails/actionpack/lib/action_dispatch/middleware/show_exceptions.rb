require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'

module ActionDispatch
  class ShowExceptions
    FAILSAFE_RESPONSE = [500, { 'Content-Type' => 'text/plain' },
      ["500 Internal Server Error\n" \
       "If you are the administrator of this website, then please read this web " \
       "application's log file and/or the web server's log file to find out what " \
       "went wrong."]]

    def initialize(app, exceptions_app)
      @app = app
      @exceptions_app = exceptions_app
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      if env['action_dispatch.show_exceptions'] == false
        raise exception
      else
        render_exception(env, exception)
      end
    end

    private

    def render_exception(env, exception)
      wrapper = ExceptionWrapper.new(env, exception)
      status  = wrapper.status_code
      env["action_dispatch.exception"] = wrapper.exception
      env["action_dispatch.original_path"] = env["PATH_INFO"]
      env["PATH_INFO"] = "/#{status}"
      response = @exceptions_app.call(env)
      response[1]['X-Cascade'] == 'pass' ? pass_response(status) : response
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      FAILSAFE_RESPONSE
    end

    def pass_response(status)
      [status, {"Content-Type" => "text/html; charset=#{Response.default_charset}", "Content-Length" => "0"}, []]
    end
  end
end
