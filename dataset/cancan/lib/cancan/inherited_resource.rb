module CanCan
  class InheritedResource < ControllerResource # :nodoc:
    def load_resource_instance
      if parent?
        #nodyna <send-2612> <SD MODERATE (private methods)>
        @controller.send :association_chain
        #nodyna <instance_variable_get-2613> <IVG COMPLEX (change-prone variable)>
        @controller.instance_variable_get("@#{instance_name}")
      elsif new_actions.include? @params[:action].to_sym
        #nodyna <send-2614> <SD EASY (private methods)>
        resource = @controller.send :build_resource
        assign_attributes(resource)
      else
        #nodyna <send-2615> <SD COMPLEX (private methods)>
        @controller.send :resource
      end
    end

    def resource_base
      #nodyna <send-2616> <SD MODERATE (private methods)>
      @controller.send :end_of_association_chain
    end
  end
end
