module Capybara
  class Window
    attr_reader :handle

    attr_reader :session

    def initialize(session, handle)
      @session = session
      @driver = session.driver
      @handle = handle
    end

    def exists?
      @driver.window_handles.include?(@handle)
    end

    def closed?
      !exists?
    end

    def current?
      @driver.current_window_handle == @handle
    rescue @driver.no_such_window_error
      false
    end

    def close
      @driver.close_window(handle)
    end

    def size
      @driver.window_size(handle)
    end

    def resize_to(width, height)
      @driver.resize_window_to(handle, width, height)
    end

    def maximize
      @driver.maximize_window(handle)
    end

    def eql?(other)
      other.kind_of?(self.class) && @session == other.session && @handle == other.handle
    end
    alias_method :==, :eql?

    def hash
      @session.hash ^ @handle.hash
    end

    def inspect
      "#<Window @handle=#{@handle.inspect}>"
    end

    private

    def raise_unless_current(what)
      unless current?
        raise Capybara::WindowError, "#{what} not current window is not possible."
      end
    end
  end
end
