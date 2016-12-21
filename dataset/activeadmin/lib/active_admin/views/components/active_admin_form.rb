module ActiveAdmin
  module Views
    class FormtasticProxy < ::Arbre::Rails::Forms::FormBuilderProxy
      def split_string_on(string, match)
        return "" unless string && match
        part_1 = string.split(Regexp.new("#{match}\\z")).first
        [part_1, match]
      end

      def opening_tag
        @opening_tag || ""
      end

      def closing_tag
        @closing_tag || ""
      end

      def to_s
        opening_tag << children.to_s << closing_tag
      end
    end
    
    class ActiveAdminForm < FormtasticProxy
      builder_method :active_admin_form_for

      def build(resource, options = {}, &block)
        @resource = resource
        options = options.deep_dup
        options[:builder] ||= ActiveAdmin::FormBuilder
        form_string = semantic_form_for(resource, options) do |f|
          @form_builder = f
        end

        @opening_tag, @closing_tag = split_string_on(form_string, "</form>")
        #nodyna <ID:instance_eval-1> <instance_eval VERY HIGH ex3>
        instance_eval(&block) if block_given?

        # Rails 4 sets multipart automatically if a file field is present,
        # but the form tag has already been rendered before the block eval.
        if multipart? && @opening_tag !~ /multipart/
          @opening_tag.sub!(/<form/, '<form enctype="multipart/form-data"')
        end
      end

      def inputs(*args, &block)
        if block_given? && block.arity == 0
          wrapped_block = proc do
            wrap_it = form_builder.already_in_an_inputs_block ? true : false
            form_builder.already_in_an_inputs_block = true
            form_builder.template.assign('has_many_block'=> true)
            content = form_builder.template.capture do
              block.call
            end
            form_builder.already_in_an_inputs_block = wrap_it
            content
          end
          insert_tag(SemanticInputsProxy, form_builder, *args, &wrapped_block)
        else
          proxy_call_to_form(:inputs, *args, &block)
        end
      end

      def input(*args)
        proxy_call_to_form :input, *args
      end

      def actions(*args, &block)
        block_given? ?
          insert_tag(SemanticActionsProxy, form_builder, *args, &block) :
          actions(*args) { commit_action_with_cancel_link }
      end

      def commit_action_with_cancel_link
        action(:submit)
        cancel_link
      end

      def has_many(*args, &block)
        insert_tag(HasManyProxy, form_builder, *args, &block)
      end

      def multipart?
        form_builder && form_builder.multipart?
      end

      def object
        form_builder.object
      end

      def form_buffers
        raise "'form_buffers' has been removed from ActiveAdmin::FormBuilder, please read https://github.com/activeadmin/activeadmin/blob/master/docs/5-forms.md for details."
      end
    end

    class SemanticInputsProxy < FormtasticProxy
      def build(form_builder, *args, &block)
        options = args.extract_options!
        legend = args.shift
        legend_tag = legend ? "<legend><span>#{legend}</span></legend>" : ""
        klasses = ["inputs"]
        klasses << options[:class] if options[:class]
        @opening_tag = "<fieldset class=\"#{klasses.join(" ")}\">#{legend_tag}<ol>"
        @closing_tag = "</ol></fieldset>"
        super(*(args << options), &block)
      end
    end

    class SemanticActionsProxy < FormtasticProxy
      def build(form_builder, *args, &block)
        @opening_tag = "<fieldset class=\"actions\"><ol>"
        @closing_tag = "</ol></fieldset>"
        super(*args, &block)
      end
    end

    class HasManyProxy < FormtasticProxy
      def build(form_builder, *args, &block)
        assoc = args[0]
        builder_options = args[1] || {}
        text_node form_builder.has_many(*args, &block)
      end
    end
  end
end
