module ActionView
  module CompiledTemplates #:nodoc:
  end

  module Context
    include CompiledTemplates
    attr_accessor :output_buffer, :view_flow

    def _prepare_context
      @view_flow     = OutputFlow.new
      @output_buffer = nil
      @virtual_path  = nil
    end

    def _layout_for(name=nil)
      name ||= :layout
      view_flow.get(name).html_safe
    end
  end
end
