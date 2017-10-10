require 'active_support/core_ext/string/output_safety'

module ActionView
  class OutputFlow #:nodoc:
    attr_reader :content

    def initialize
      @content = Hash.new { |h,k| h[k] = ActiveSupport::SafeBuffer.new }
    end

    def get(key)
      @content[key]
    end

    def set(key, value)
      @content[key] = value
    end

    def append(key, value)
      @content[key] << value
    end
    alias_method :append!, :append

  end

  class StreamingFlow < OutputFlow #:nodoc:
    def initialize(view, fiber)
      @view    = view
      @parent  = nil
      @child   = view.output_buffer
      @content = view.view_flow.content
      @fiber   = fiber
      @root    = Fiber.current.object_id
    end

    def get(key)
      return super if @content.key?(key)

      if inside_fiber?
        view = @view

        begin
          @waiting_for = key
          view.output_buffer, @parent = @child, view.output_buffer
          Fiber.yield
        ensure
          @waiting_for = nil
          view.output_buffer, @child = @parent, view.output_buffer
        end
      end

      super
    end

    def append!(key, value)
      super
      @fiber.resume if @waiting_for == key
    end

    private

    def inside_fiber?
      Fiber.current.object_id != @root
    end
  end
end
