require 'capybara/session/matchers'

module Capybara

  class Session
    include Capybara::SessionMatchers

    NODE_METHODS = [
      :all, :first, :attach_file, :text, :check, :choose,
      :click_link_or_button, :click_button, :click_link, :field_labeled,
      :fill_in, :find, :find_all, :find_button, :find_by_id, :find_field, :find_link,
      :has_content?, :has_text?, :has_css?, :has_no_content?, :has_no_text?,
      :has_no_css?, :has_no_xpath?, :resolve, :has_xpath?, :select, :uncheck,
      :has_link?, :has_no_link?, :has_button?, :has_no_button?, :has_field?,
      :has_no_field?, :has_checked_field?, :has_unchecked_field?,
      :has_no_table?, :has_table?, :unselect, :has_select?, :has_no_select?,
      :has_selector?, :has_no_selector?, :click_on, :has_no_checked_field?,
      :has_no_unchecked_field?, :query, :assert_selector, :assert_no_selector,
      :refute_selector, :assert_text, :assert_no_text
    ]
    DOCUMENT_METHODS = [
      :title, :assert_title, :assert_no_title, :has_title?, :has_no_title?
    ]
    SESSION_METHODS = [
      :body, :html, :source, :current_url, :current_host, :current_path,
      :execute_script, :evaluate_script, :visit, :go_back, :go_forward,
      :within, :within_fieldset, :within_table, :within_frame, :current_window,
      :windows, :open_new_window, :switch_to_window, :within_window, :window_opened_by,
      :save_page, :save_and_open_page, :save_screenshot,
      :save_and_open_screenshot, :reset_session!, :response_headers,
      :status_code, :current_scope,
      :assert_current_path, :assert_no_current_path, :has_current_path?, :has_no_current_path?
    ] + DOCUMENT_METHODS
    MODAL_METHODS = [
      :accept_alert, :accept_confirm, :dismiss_confirm, :accept_prompt,
      :dismiss_prompt
    ]
    DSL_METHODS = NODE_METHODS + SESSION_METHODS + MODAL_METHODS

    attr_reader :mode, :app, :server
    attr_accessor :synchronized

    def initialize(mode, app=nil)
      @mode = mode
      @app = app
      if Capybara.run_server and @app and driver.needs_server?
        @server = Capybara::Server.new(@app).boot
      else
        @server = nil
      end
      @touched = false
    end

    def driver
      @driver ||= begin
        unless Capybara.drivers.has_key?(mode)
          other_drivers = Capybara.drivers.keys.map { |key| key.inspect }
          raise Capybara::DriverNotFoundError, "no driver called #{mode.inspect} was found, available drivers: #{other_drivers.join(', ')}"
        end
        Capybara.drivers[mode].call(app)
      end
    end

    def reset!
      if @touched
        driver.reset!
        assert_no_selector :xpath, "/html/body/*" if driver.browser_initialized?
        @touched = false
      end
      raise_server_error!
    end
    alias_method :cleanup!, :reset!
    alias_method :reset_session!, :reset!

    def raise_server_error!
      raise @server.error if Capybara.raise_server_errors and @server and @server.error
    ensure
      @server.reset_error! if @server
    end

    def response_headers
      driver.response_headers
    end

    def status_code
      driver.status_code
    end

    def html
      driver.html
    end
    alias_method :body, :html
    alias_method :source, :html

    def current_path
      path = URI.parse(current_url).path
      path if path and not path.empty?
    end

    def current_host
      uri = URI.parse(current_url)
      "#{uri.scheme}://#{uri.host}" if uri.host
    end

    def current_url
      driver.current_url
    end

    def visit(url)
      raise_server_error!

      url = url.to_s
      @touched = true

      url_relative = URI.parse(url).scheme.nil?

      if url_relative && Capybara.app_host
        url = Capybara.app_host + url
        url_relative = false
      end

      if @server
        url = "http://#{@server.host}:#{@server.port}" + url if url_relative

        if Capybara.always_include_port
          uri = URI.parse(url)
          uri.port = @server.port if uri.port == uri.default_port
          url = uri.to_s
        end
      end

      driver.visit(url)
    end

    def go_back
      driver.go_back
    end

    def go_forward
      driver.go_forward
    end

    def within(*args)
      new_scope = if args.first.is_a?(Capybara::Node::Base) then args.first else find(*args) end
      begin
        scopes.push(new_scope)
        yield
      ensure
        scopes.pop
      end
    end

    def within_fieldset(locator)
      within :fieldset, locator do
        yield
      end
    end

    def within_table(locator)
      within :table, locator do
        yield
      end
    end

    def within_frame(frame_handle)
      scopes.push(nil)
      driver.within_frame(frame_handle) do
        yield
      end
    ensure
      scopes.pop
    end

    def current_window
      Window.new(self, driver.current_window_handle)
    end

    def windows
      driver.window_handles.map do |handle|
        Window.new(self, handle)
      end
    end

    def open_new_window
      window_opened_by do
        driver.open_new_window
      end
    end

    def switch_to_window(window = nil, options= {})
      if window.is_a? Hash
        options = window
        window = nil
      end
      block_given = block_given?
      if window && block_given
        raise ArgumentError, "`switch_to_window` can take either a block or a window, not both"
      elsif !window && !block_given
        raise ArgumentError, "`switch_to_window`: either window or block should be provided"
      elsif scopes.size > 1
        raise Capybara::ScopeError, "`switch_to_window` is not supposed to be invoked from "\
                                    "`within`'s, `within_frame`'s' or `within_window`'s' block."
      end

      if window
        driver.switch_to_window(window.handle)
        window
      else
        wait_time = Capybara::Query.new(options).wait
        document.synchronize(wait_time, errors: [Capybara::WindowError]) do
          original_window_handle = driver.current_window_handle
          begin
            driver.window_handles.each do |handle|
              driver.switch_to_window handle
              if yield
                return Window.new(self, handle)
              end
            end
          rescue => e
            driver.switch_to_window(original_window_handle)
            raise e
          else
            driver.switch_to_window(original_window_handle)
            raise Capybara::WindowError, "Could not find a window matching block/lambda"
          end
        end
      end
    end

    def within_window(window_or_handle)
      if window_or_handle.instance_of?(Capybara::Window)
        original = current_window
        switch_to_window(window_or_handle) unless original == window_or_handle
        scopes << nil
        begin
          yield
        ensure
          @scopes.pop
          switch_to_window(original) unless original == window_or_handle
        end
      elsif window_or_handle.is_a?(Proc)
        original = current_window
        switch_to_window { window_or_handle.call }
        scopes << nil
        begin
          yield
        ensure
          @scopes.pop
          switch_to_window(original)
        end
      else
        offending_line = caller.first
        file_line = offending_line.match(/^(.+?):(\d+)/)[0]
        warn "DEPRECATION WARNING: Passing string argument to #within_window is deprecated. "\
             "Pass window object or lambda. (called from #{file_line})"
        begin
          scopes << nil
          driver.within_window(window_or_handle) { yield }
        ensure
          @scopes.pop
        end
      end
    end

    def window_opened_by(options = {}, &block)
      old_handles = driver.window_handles
      block.call

      wait_time = Capybara::Query.new(options).wait
      document.synchronize(wait_time, errors: [Capybara::WindowError]) do
        opened_handles = (driver.window_handles - old_handles)
        if opened_handles.size != 1
          raise Capybara::WindowError, "block passed to #window_opened_by "\
                                       "opened #{opened_handles.size} windows instead of 1"
        end
        Window.new(self, opened_handles.first)
      end
    end

    def execute_script(script)
      @touched = true
      driver.execute_script(script)
    end

    def evaluate_script(script)
      @touched = true
      driver.evaluate_script(script)
    end

    def accept_alert(text_or_options=nil, options={}, &blk)
      if text_or_options.is_a? Hash
        options=text_or_options
      else
        options[:text]=text_or_options
      end

      driver.accept_modal(:alert, options, &blk)
    end

    def accept_confirm(text_or_options=nil, options={}, &blk)
      if text_or_options.is_a? Hash
        options=text_or_options
      else
        options[:text]=text_or_options
      end

      driver.accept_modal(:confirm, options, &blk)
    end

    def dismiss_confirm(text_or_options=nil, options={}, &blk)
      if text_or_options.is_a? Hash
        options=text_or_options
      else
        options[:text]=text_or_options
      end

      driver.dismiss_modal(:confirm, options, &blk)
    end

    def accept_prompt(text_or_options=nil, options={}, &blk)
      if text_or_options.is_a? Hash
        options=text_or_options
      else
        options[:text]=text_or_options
      end

      driver.accept_modal(:prompt, options, &blk)
    end

    def dismiss_prompt(text_or_options=nil, options={}, &blk)
      if text_or_options.is_a? Hash
        options=text_or_options
      else
        options[:text]=text_or_options
      end

      driver.dismiss_modal(:prompt, options, &blk)
    end

    def save_page(path = nil)
      path = prepare_path(path, 'html')
      File.write(path, Capybara::Helpers.inject_asset_host(body), mode: 'wb')
      path
    end

    def save_and_open_page(path = nil)
      path = save_page(path)
      open_file(path)
    end

    def save_screenshot(path = nil, options = {})
      path = prepare_path(path, 'png')
      driver.save_screenshot(path, options)
      path
    end

    def save_and_open_screenshot(path = nil, options = {})
      path = save_screenshot(path, options)
      open_file(path)
    end

    def document
      @document ||= Capybara::Node::Document.new(self, driver)
    end

    NODE_METHODS.each do |method|
      #nodyna <define_method-2650> <not yet classified>
      define_method method do |*args, &block|
        @touched = true
        #nodyna <send-2651> <not yet classified>
        current_scope.send(method, *args, &block)
      end
    end

    DOCUMENT_METHODS.each do |method|
      #nodyna <define_method-2652> <not yet classified>
      define_method method do |*args, &block|
        #nodyna <send-2653> <not yet classified>
        document.send(method, *args, &block)
      end
    end

    def inspect
      %(#<Capybara::Session>)
    end

    def current_scope
      scopes.last || document
    end

  private

    def open_file(path)
      begin
        require "launchy"
        Launchy.open(path)
      rescue LoadError
        warn "File saved to #{path}."
        warn "Please install the launchy gem to open the file automatically."
      end
    end

    def prepare_path(path, extension)
      path = default_path(extension) if path.nil?
      FileUtils.mkdir_p(File.dirname(path))
      path
    end

    def default_path(extension)
      timestamp = Time.new.strftime("%Y%m%d%H%M%S")
      path = "capybara-#{timestamp}#{rand(10**10)}.#{extension}"
      File.expand_path(path, Capybara.save_and_open_page_path)
    end

    def scopes
      @scopes ||= [nil]
    end
  end
end
