require 'timeout'
require 'nokogiri'
require 'xpath'

module Capybara
  class CapybaraError < StandardError; end
  class DriverNotFoundError < CapybaraError; end
  class FrozenInTime < CapybaraError; end
  class ElementNotFound < CapybaraError; end
  class ModalNotFound < CapybaraError; end
  class Ambiguous < ElementNotFound; end
  class ExpectationNotMet < ElementNotFound; end
  class FileNotFound < CapybaraError; end
  class UnselectNotAllowed < CapybaraError; end
  class NotSupportedByDriverError < CapybaraError; end
  class InfiniteRedirectError < CapybaraError; end
  class ScopeError < CapybaraError; end
  class WindowError < CapybaraError; end
  class ReadOnlyElementError < CapybaraError; end

  class << self
    attr_accessor :asset_host, :app_host, :run_server, :default_host, :always_include_port
    attr_accessor :server_port, :exact, :match, :exact_options, :visible_text_only
    attr_accessor :default_selector, :default_max_wait_time, :ignore_hidden_elements
    attr_accessor :save_and_open_page_path, :wait_on_first_by_default, :automatic_reload, :raise_server_errors, :server_errors
    attr_writer :default_driver, :current_driver, :javascript_driver, :session_name, :server_host
    attr_accessor :app

    def configure
      yield self
    end

    def register_driver(name, &block)
      drivers[name] = block
    end

    def add_selector(name, &block)
      Capybara::Selector.add(name, &block)
    end

    def drivers
      @drivers ||= {}
    end

    def server(&block)
      if block_given?
        @server = block
      else
        @server
      end
    end

    def string(html)
      Capybara::Node::Simple.new(html)
    end

    def run_default_server(app, port)
      require 'rack/handler/webrick'
      Rack::Handler::WEBrick.run(app, :Host => server_host, :Port => port, :AccessLog => [], :Logger => WEBrick::Log::new(nil, 0))
    end

    def default_driver
      @default_driver || :rack_test
    end

    def current_driver
      @current_driver || default_driver
    end
    alias_method :mode, :current_driver

    def javascript_driver
      @javascript_driver || :selenium
    end

    def use_default_driver
      @current_driver = nil
    end

    def using_driver(driver)
      previous_driver = Capybara.current_driver
      Capybara.current_driver = driver
      yield
    ensure
      @current_driver = previous_driver
    end

    def server_host
      @server_host || '127.0.0.1'
    end

    def using_wait_time(seconds)
      previous_wait_time = Capybara.default_max_wait_time
      Capybara.default_max_wait_time = seconds
      yield
    ensure
      Capybara.default_max_wait_time = previous_wait_time
    end

    def current_session
      session_pool["#{current_driver}:#{session_name}:#{app.object_id}"] ||= Capybara::Session.new(current_driver, app)
    end

    def reset_sessions!
      session_pool.each { |mode, session| session.reset! }
    end
    alias_method :reset!, :reset_sessions!

    def session_name
      @session_name ||= :default
    end

    def using_session(name)
      previous_session_name = self.session_name
      self.session_name = name
      yield
    ensure
      self.session_name = previous_session_name
    end

    def HTML(html)
      Nokogiri::HTML(html).tap do |document|
        document.xpath('//textarea').each do |textarea|
          textarea.content=textarea.content.sub(/\A\n/,'')
        end
      end
    end
    
    def default_wait_time
      deprecate('default_wait_time', 'default_max_wait_time', true)
      default_max_wait_time
    end
    
    def default_wait_time=(t)
      deprecate('default_wait_time=', 'default_max_wait_time=')
      self.default_max_wait_time = t
    end

    def included(base)
      #nodyna <send-2625> <SD TRIVIAL (public methods)>
      base.send(:include, Capybara::DSL)
      warn "`include Capybara` is deprecated. Please use `include Capybara::DSL` instead."
    end

    def deprecate(method, alternate_method, once=false)
      @deprecation_notified ||= {}
      warn "DEPRECATED: ##{method} is deprecated, please use ##{alternate_method} instead" unless once and @deprecation_notified[method]
      @deprecation_notified[method]=true
    end

  private

    def session_pool
      @session_pool ||= {}
    end
  end

  self.default_driver = nil
  self.current_driver = nil
  self.server_host = nil

  module Driver; end
  module RackTest; end
  module Selenium; end

  require 'capybara/helpers'
  require 'capybara/session'
  require 'capybara/dsl'
  require 'capybara/window'
  require 'capybara/server'
  require 'capybara/selector'
  require 'capybara/result'
  require 'capybara/version'

  require 'capybara/queries/base_query'
  require 'capybara/query'
  require 'capybara/queries/text_query'
  require 'capybara/queries/title_query'
  require 'capybara/queries/current_path_query'
  
  require 'capybara/node/finders'
  require 'capybara/node/matchers'
  require 'capybara/node/actions'
  require 'capybara/node/document_matchers'
  require 'capybara/node/simple'
  require 'capybara/node/base'
  require 'capybara/node/element'
  require 'capybara/node/document'

  require 'capybara/driver/base'
  require 'capybara/driver/node'

  require 'capybara/rack_test/driver'
  require 'capybara/rack_test/node'
  require 'capybara/rack_test/form'
  require 'capybara/rack_test/browser'
  require 'capybara/rack_test/css_handlers.rb'

  require 'capybara/selenium/node'
  require 'capybara/selenium/driver'
end

Capybara.configure do |config|
  config.always_include_port = false
  config.run_server = true
  config.server {|app, port| Capybara.run_default_server(app, port)}
  config.default_selector = :css
  config.default_max_wait_time = 2
  config.ignore_hidden_elements = true
  config.default_host = "http://www.example.com"
  config.automatic_reload = true
  config.match = :smart
  config.exact = false
  config.raise_server_errors = true
  config.server_errors = [StandardError]
  config.visible_text_only = false
  config.wait_on_first_by_default = false
end

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app)
end

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app)
end
