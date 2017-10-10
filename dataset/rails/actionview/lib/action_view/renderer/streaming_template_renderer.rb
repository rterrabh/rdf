require 'fiber'

module ActionView
  class StreamingTemplateRenderer < TemplateRenderer #:nodoc:
    class Body #:nodoc:
      def initialize(&start)
        @start = start
      end

      def each(&block)
        begin
          @start.call(block)
        rescue Exception => exception
          log_error(exception)
          block.call ActionView::Base.streaming_completion_on_exception
        end
        self
      end

      private

      def log_error(exception) #:nodoc:
        logger = ActionView::Base.logger
        return unless logger

        message = "\n#{exception.class} (#{exception.message}):\n"
        message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
        message << "  " << exception.backtrace.join("\n  ")
        logger.fatal("#{message}\n\n")
      end
    end

    def render_template(template, layout_name = nil, locals = {}) #:nodoc:
      return [super] unless layout_name && template.supports_streaming?

      locals ||= {}
      layout   = layout_name && find_layout(layout_name, locals.keys)

      Body.new do |buffer|
        delayed_render(buffer, template, layout, @view, locals)
      end
    end

    private

    def delayed_render(buffer, template, layout, view, locals)
      output  = ActionView::StreamingBuffer.new(buffer)
      yielder = lambda { |*name| view._layout_for(*name) }

      instrument(:template, :identifier => template.identifier, :layout => layout.try(:virtual_path)) do
        fiber = Fiber.new do
          if layout
            layout.render(view, locals, output, &yielder)
          else
            output.safe_concat view._layout_for
          end
        end

        view.view_flow = StreamingFlow.new(view, fiber)

        fiber.resume

        if fiber.alive?
          content = template.render(view, locals, &yielder)

          view.view_flow.set(:layout, content)

          fiber.resume while fiber.alive?
        end
      end
    end
  end
end
