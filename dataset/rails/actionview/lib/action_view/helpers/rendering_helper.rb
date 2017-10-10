module ActionView
  module Helpers
    module RenderingHelper
      def render(options = {}, locals = {}, &block)
        case options
        when Hash
          if block_given?
            view_renderer.render_partial(self, options.merge(:partial => options[:layout]), &block)
          else
            view_renderer.render(self, options)
          end
        else
          view_renderer.render_partial(self, :partial => options, :locals => locals)
        end
      end

      def _layout_for(*args, &block)
        name = args.first

        if block && !name.is_a?(Symbol)
          capture(*args, &block)
        else
          super
        end
      end
    end
  end
end
