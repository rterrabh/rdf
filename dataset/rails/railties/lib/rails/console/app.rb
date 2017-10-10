require 'active_support/all'
require 'action_controller'

module Rails
  module ConsoleMethods
    def app(create=false)
      @app_integration_instance = nil if create
      @app_integration_instance ||= new_session do |sess|
        sess.host! "www.example.com"
      end
    end

    def new_session
      app = Rails.application
      session = ActionDispatch::Integration::Session.new(app)
      yield session if block_given?
      session
    end

    def reload!(print=true)
      puts "Reloading..." if print
      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!
      true
    end
  end
end
