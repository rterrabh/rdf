require 'active_support/core_ext/string/output_safety'

module ActionView
  module Helpers
    module CaptureHelper
      def capture(*args)
        value = nil
        buffer = with_output_buffer { value = yield(*args) }
        if string = buffer.presence || value and string.is_a?(String)
          ERB::Util.html_escape string
        end
      end

      def content_for(name, content = nil, options = {}, &block)
        if content || block_given?
          if block_given?
            options = content if content
            content = capture(&block)
          end
          if content
            options[:flush] ? @view_flow.set(name, content) : @view_flow.append(name, content)
          end
          nil
        else
          @view_flow.get(name).presence
        end
      end

      def provide(name, content = nil, &block)
        content = capture(&block) if block_given?
        result = @view_flow.append!(name, content) if content
        result unless content
      end

      def content_for?(name)
        @view_flow.get(name).present?
      end

      def with_output_buffer(buf = nil) #:nodoc:
        unless buf
          buf = ActionView::OutputBuffer.new
          if output_buffer && output_buffer.respond_to?(:encoding)
            buf.force_encoding(output_buffer.encoding)
          end
        end
        self.output_buffer, old_buffer = buf, output_buffer
        yield
        output_buffer
      ensure
        self.output_buffer = old_buffer
      end
    end
  end
end
