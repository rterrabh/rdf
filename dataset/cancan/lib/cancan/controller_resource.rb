module CanCan
  class ControllerResource # :nodoc:
    def self.add_before_filter(controller_class, method, *args)
      options = args.extract_options!
      resource_name = args.first
      before_filter_method = options.delete(:prepend) ? :prepend_before_filter : :before_filter
      #nodyna <send-2596> <SD MODERATE (change-prone variable)>
      controller_class.send(before_filter_method, options.slice(:only, :except, :if, :unless)) do |controller|
        #nodyna <send-2597> <SD MODERATE (change-prone variable)>
        controller.class.cancan_resource_class.new(controller, resource_name, options.except(:only, :except, :if, :unless)).send(method)
      end
    end

    def initialize(controller, *args)
      @controller = controller
      @params = controller.params
      @options = args.extract_options!
      @name = args.first
      raise CanCan::ImplementationRemoved, "The :nested option is no longer supported, instead use :through with separate load/authorize call." if @options[:nested]
      raise CanCan::ImplementationRemoved, "The :name option is no longer supported, instead pass the name as the first argument." if @options[:name]
      raise CanCan::ImplementationRemoved, "The :resource option has been renamed back to :class, use false if no class." if @options[:resource]
    end

    def load_and_authorize_resource
      load_resource
      authorize_resource
    end

    def load_resource
      unless skip?(:load)
        if load_instance?
          self.resource_instance ||= load_resource_instance
        elsif load_collection?
          self.collection_instance ||= load_collection
        end
      end
    end

    def authorize_resource
      unless skip?(:authorize)
        @controller.authorize!(authorization_action, resource_instance || resource_class_with_parent)
      end
    end

    def parent?
      @options.has_key?(:parent) ? @options[:parent] : @name && @name != name_from_controller.to_sym
    end

    def skip?(behavior) # This could probably use some refactoring
      options = @controller.class.cancan_skipper[behavior][@name]
      if options.nil?
        false
      elsif options == {}
        true
      elsif options[:except] && ![options[:except]].flatten.include?(@params[:action].to_sym)
        true
      elsif [options[:only]].flatten.include?(@params[:action].to_sym)
        true
      end
    end

    protected

    def load_resource_instance
      if !parent? && new_actions.include?(@params[:action].to_sym)
        build_resource
      elsif id_param || @options[:singleton]
        find_resource
      end
    end

    def load_instance?
      parent? || member_action?
    end

    def load_collection?
      resource_base.respond_to?(:accessible_by) && !current_ability.has_block?(authorization_action, resource_class)
    end

    def load_collection
      resource_base.accessible_by(current_ability, authorization_action)
    end

    def build_resource
      resource = resource_base.new(resource_params || {})
      assign_attributes(resource)
    end

    def assign_attributes(resource)
      #nodyna <send-2598> <SD COMPLEX (change-prone variable)>
      resource.send("#{parent_name}=", parent_resource) if @options[:singleton] && parent_resource
      initial_attributes.each do |attr_name, value|
        #nodyna <send-2599> <SD COMPLEX (array)>
        resource.send("#{attr_name}=", value)
      end
      resource
    end

    def initial_attributes
      current_ability.attributes_for(@params[:action].to_sym, resource_class).delete_if do |key, value|
        resource_params && resource_params.include?(key)
      end
    end

    def find_resource
      if @options[:singleton] && parent_resource.respond_to?(name)
        #nodyna <send-2600> <SD COMPLEX (change-prone variable)>
        parent_resource.send(name)
      else
        if @options[:find_by]
          if resource_base.respond_to? "find_by_#{@options[:find_by]}!"
            #nodyna <send-2601> <SD COMPLEX (change-prone variable)>
            resource_base.send("find_by_#{@options[:find_by]}!", id_param)
          elsif resource_base.respond_to? "find_by"
            #nodyna <send-2602> <SD COMPLEX (change-prone variable)>
            resource_base.send("find_by", { @options[:find_by].to_sym => id_param })
          else
            #nodyna <send-2603> <SD COMPLEX (change-prone variable)>
            resource_base.send(@options[:find_by], id_param)
          end
        else
          adapter.find(resource_base, id_param)
        end
      end
    end

    def adapter
      ModelAdapters::AbstractAdapter.adapter_class(resource_class)
    end

    def authorization_action
      parent? ? :show : @params[:action].to_sym
    end

    def id_param
      if @options[:id_param]
        @params[@options[:id_param]]
      else
        @params[parent? ? :"#{name}_id" : :id]
      end.to_s
    end

    def member_action?
      new_actions.include?(@params[:action].to_sym) || @options[:singleton] || ( (@params[:id] || @params[@options[:id_param]]) && !collection_actions.include?(@params[:action].to_sym))
    end

    def resource_class
      case @options[:class]
      when false  then name.to_sym
      when nil    then namespaced_name.to_s.camelize.constantize
      when String then @options[:class].constantize
      else @options[:class]
      end
    end

    def resource_class_with_parent
      parent_resource ? {parent_resource => resource_class} : resource_class
    end

    def resource_instance=(instance)
      #nodyna <instance_variable_set-2604> <IVS COMPLEX (change-prone variable)>
      @controller.instance_variable_set("@#{instance_name}", instance)
    end

    def resource_instance
      #nodyna <instance_variable_get-2605> <IVS COMPLEX (change-prone variable)>
      @controller.instance_variable_get("@#{instance_name}") if load_instance?
    end

    def collection_instance=(instance)
      #nodyna <instance_variable_set-2606> <IVS COMPLEX (change-prone variable)>
      @controller.instance_variable_set("@#{instance_name.to_s.pluralize}", instance)
    end

    def collection_instance
      #nodyna <instance_variable_get-2607> <IVS COMPLEX (change-prone variable)>
      @controller.instance_variable_get("@#{instance_name.to_s.pluralize}")
    end

    def resource_base
      if @options[:through]
        if parent_resource
          #nodyna <send-2608> <SD COMPLEX (change-prone variable)>
          @options[:singleton] ? resource_class : parent_resource.send(@options[:through_association] || name.to_s.pluralize)
        elsif @options[:shallow]
          resource_class
        else
          raise AccessDenied.new(nil, authorization_action, resource_class) # maybe this should be a record not found error instead?
        end
      else
        resource_class
      end
    end

    def parent_name
      @options[:through] && [@options[:through]].flatten.detect { |i| fetch_parent(i) }
    end

    def parent_resource
      parent_name && fetch_parent(parent_name)
    end

    def fetch_parent(name)
      if @controller.instance_variable_defined? "@#{name}"
        #nodyna <instance_variable_get-2609> <IVG COMPLEX (change-prone variable)>
        @controller.instance_variable_get("@#{name}")
      elsif @controller.respond_to?(name, true)
        #nodyna <send-2610> <SD COMPLEX (change-prone variable)>
        @controller.send(name)
      end
    end

    def current_ability
      #nodyna <send-2611> <SD EASY (private access)>
      @controller.send(:current_ability)
    end

    def name
      @name || name_from_controller
    end

    def resource_params
      if @options[:class]
        params_key = extract_key(@options[:class])
        return @params[params_key] if @params[params_key]
      end

      resource_params_by_namespaced_name
    end

    def resource_params_by_namespaced_name
      @params[extract_key(namespaced_name)]
    end

    def namespace
      @params[:controller].split(/::|\//)[0..-2]
    end

    def namespaced_name
      [namespace, name.camelize].join('::').singularize.camelize.constantize
    rescue NameError
      name
    end

    def name_from_controller
      @params[:controller].sub("Controller", "").underscore.split('/').last.singularize
    end

    def instance_name
      @options[:instance_name] || name
    end

    def collection_actions
      [:index] + [@options[:collection]].flatten
    end

    def new_actions
      [:new, :create] + [@options[:new]].flatten
    end

    private

    def extract_key(value)
       value.to_s.underscore.gsub('/', '_')
    end
  end
end
