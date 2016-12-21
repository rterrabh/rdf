module ActiveAdmin
  module Views

    class SidebarSection < Panel
      builder_method :sidebar_section

      # Takes a ActiveAdmin::SidebarSection instance
      def build(section)
        @section = section
        super(@section.title, icon: @section.icon)
        add_class @section.custom_class if @section.custom_class
        self.id = @section.id
        build_sidebar_content
      end

      protected

      def build_sidebar_content
        if @section.block
          #nodyna <ID:instance_exec-21> <instance_exec VERY HIGH ex1>
          rvalue = instance_exec(&@section.block)
          self << rvalue if rvalue.is_a?(String)
        else
          render(@section.partial_name)
        end
      end
    end

  end
end
