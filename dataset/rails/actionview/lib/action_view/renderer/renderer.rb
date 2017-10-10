module ActionView
  class Renderer
    attr_accessor :lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render(context, options)
      if options.key?(:partial)
        render_partial(context, options)
      else
        render_template(context, options)
      end
    end

    def render_body(context, options)
      if options.key?(:partial)
        [render_partial(context, options)]
      else
        StreamingTemplateRenderer.new(@lookup_context).render(context, options)
      end
    end

    def render_template(context, options) #:nodoc:
      TemplateRenderer.new(@lookup_context).render(context, options)
    end

    def render_partial(context, options, &block) #:nodoc:
      PartialRenderer.new(@lookup_context).render(context, options, block)
    end
  end
end
