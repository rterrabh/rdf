module Paperclip
  class HasAttachedFile
    def self.define_on(klass, name, options)
      new(klass, name, options).define
    end

    def initialize(klass, name, options)
      @klass = klass
      @name = name
      @options = options
    end

    def define
      define_flush_errors
      define_getters
      define_setter
      define_query
      register_new_attachment
      add_active_record_callbacks
      add_paperclip_callbacks
      add_required_validations
    end

    private

    def define_flush_errors
      #nodyna <ID:send-21> <send VERY LOW ex1>
      @klass.send(:validates_each, @name) do |record, attr, value|
        #nodyna <ID:send-22> <send VERY HIGH ex3>
        attachment = record.send(@name)
        #nodyna <ID:send-23> <send LOW ex4>
        attachment.send(:flush_errors)
      end
    end

    def define_getters
      define_instance_getter
      define_class_getter
    end

    def define_instance_getter
      name = @name
      options = @options

      #nodyna <ID:send-24> <send MEDIUM ex4>
      #nodyna <ID:define_method-3> <define_method VERY HIGH ex2>
      @klass.send :define_method, @name do |*args|
        ivar = "@attachment_#{name}"
        attachment = instance_variable_get(ivar)

        if attachment.nil?
          attachment = Attachment.new(name, self, options)
          instance_variable_set(ivar, attachment)
        end

        if args.length > 0
          attachment.to_s(args.first)
        else
          attachment
        end
      end
    end

    def define_class_getter
      @klass.extend(ClassMethods)
    end

    def define_setter
      name = @name
      #nodyna <ID:send-25> <send MEDIUM ex4>
      #nodyna <ID:define_method-4> <define_method VERY HIGH ex2>
      @klass.send :define_method, "#{@name}=" do |file|
        #nodyna <ID:send-26> <send VERY HIGH ex3>
        send(name).assign(file)
      end
    end

    def define_query
      name = @name
      #nodyna <ID:send-27> <send MEDIUM ex4>
      #nodyna <ID:define_method-5> <define_method VERY HIGH ex2>
      @klass.send :define_method, "#{@name}?" do
        #nodyna <ID:send-28> <send VERY HIGH ex3>
        send(name).file?
      end
    end

    def register_new_attachment
      Paperclip::AttachmentRegistry.register(@klass, @name, @options)
    end

    def add_required_validations
      options = Paperclip::Attachment.default_options.deep_merge(@options)
      if options[:validate_media_type] != false
        name = @name
        @klass.validates_media_type_spoof_detection name,
          #nodyna <ID:send-29> <send VERY HIGH ex3>
          :if => ->(instance){ instance.send(name).dirty? }
      end
    end

    def add_active_record_callbacks
      name = @name
      #nodyna <ID:send-30> <send VERY LOW ex1>
      #nodyna <ID:send-30> <send VERY HIGH ex3>
      #nodyna <ID:send-30> <send VERY LOW ex1>
      @klass.send(:after_save) { send(name).send(:save) }
      #nodyna <ID:send-31> <send VERY LOW ex1>
      #nodyna <ID:send-31> <send VERY HIGH ex3>
      #nodyna <ID:send-31> <send LOW ex4>
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      #nodyna <ID:send-32> <send VERY LOW ex1>
      #nodyna <ID:send-32> <send VERY HIGH ex3>
      #nodyna <ID:send-32> <send VERY LOW ex1>
      @klass.send(:after_commit, :on => :destroy) { send(name).send(:flush_deletes) }
    end

    def add_paperclip_callbacks
      #nodyna <ID:send-33> <send VERY LOW ex1>
      @klass.send(
        :define_paperclip_callbacks,
        :post_process, :"#{@name}_post_process")
    end

    module ClassMethods
      def attachment_definitions
        Paperclip::AttachmentRegistry.definitions_for(self)
      end
    end
  end
end
