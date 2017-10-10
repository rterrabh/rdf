require 'active_support/deprecation/reporting'

module ActionDispatch
  class Reloader
    include ActiveSupport::Callbacks
    include ActiveSupport::Deprecation::Reporting

    define_callbacks :prepare
    define_callbacks :cleanup

    def self.to_prepare(*args, &block)
      unless block_given?
        warn "to_prepare without a block is deprecated. Please use a block"
      end
      set_callback(:prepare, *args, &block)
    end

    def self.to_cleanup(*args, &block)
      unless block_given?
        warn "to_cleanup without a block is deprecated. Please use a block"
      end
      set_callback(:cleanup, *args, &block)
    end

    def self.prepare!
      new(nil).prepare!
    end

    def self.cleanup!
      new(nil).cleanup!
    end

    def initialize(app, condition=nil)
      @app = app
      @condition = condition || lambda { true }
      @validated = true
    end

    def call(env)
      @validated = @condition.call
      prepare!

      response = @app.call(env)
      response[2] = ::Rack::BodyProxy.new(response[2]) { cleanup! }

      response
    rescue Exception
      cleanup!
      raise
    end

    def prepare! #:nodoc:
      run_callbacks :prepare if validated?
    end

    def cleanup! #:nodoc:
      run_callbacks :cleanup if validated?
    ensure
      @validated = true
    end

    private

    def validated? #:nodoc:
      @validated
    end
  end
end
