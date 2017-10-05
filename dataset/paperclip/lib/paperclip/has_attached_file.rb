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
      #nodyna <ID:send-21> <SD TRIVIAL (public methods)>
      @klass.send(:validates_each, @name) do |record, attr, value|
        #nodyna <ID:send-22> <SD COMPLEX (change-prone variables)>
        attachment = record.send(@name)
        #nodyna <ID:send-23> <SD EASY (private methods)>
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

      #nodyna <ID:send-24> <SD MODERATE (private methods)>
      #nodyna <ID:define_method-3> <DM COMPLEX (events)>
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
      #nodyna <ID:send-25> <SD MODERATE (private methods)>
      #nodyna <ID:define_method-4> <DM COMPLEX (events)>
      @klass.send :define_method, "#{@name}=" do |file|
        #nodyna <ID:send-26> <SD COMPLEX (change-prone variables)>
        send(name).assign(file)
      end
    end

    def define_query
      name = @name
      #nodyna <ID:send-27> <SD MODERATE (private methods)>
      #nodyna <ID:define_method-5> <DM COMPLEX (events)>
      @klass.send :define_method, "#{@name}?" do
        #nodyna <ID:send-28> <SD COMPLEX (change-prone variables)>
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
          #nodyna <ID:send-29> <SD COMPLEX (change-prone variables)>
          :if => ->(instance){ instance.send(name).dirty? }
      end
    end

    def add_active_record_callbacks
      name = @name
      #nodyna <ID:send-30> <SD TRIVIAL (public methods)>
      #nodyna <ID:send-30> <SD COMPLEX (change-prone variables)>
      #nodyna <ID:send-30> <SD TRIVIAL (public methods)>
      @klass.send(:after_save) { send(name).send(:save) }
      #nodyna <ID:send-31> <SD TRIVIAL (public methods)>
      #nodyna <ID:send-31> <SD COMPLEX (change-prone variables)>
      #nodyna <ID:send-31> <SD EASY (private methods)>
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      #nodyna <ID:send-32> <SD TRIVIAL (public methods)>
      #nodyna <ID:send-32> <SD COMPLEX (change-prone variables)>
      #nodyna <ID:send-32> <SD TRIVIAL (public methods)>
      @klass.send(:after_commit, :on => :destroy) { send(name).send(:flush_deletes) }
    end

    def add_paperclip_callbacks
      #nodyna <ID:send-33> <SD TRIVIAL (public methods)>
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
