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
      #nodyna <send-715> <SD TRIVIAL (public methods)>
      @klass.send(:validates_each, @name) do |record, attr, value|
        #nodyna <send-716> <SD COMPLEX (change-prone variables)>
        attachment = record.send(@name)
        #nodyna <send-717> <SD EASY (private methods)>
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

      #nodyna <send-718> <SD MODERATE (private methods)>
      #nodyna <define_method-719> <DM COMPLEX (events)>
      @klass.send :define_method, @name do |*args|
        ivar = "@attachment_#{name}"
        #nodyna <instance_variable_get-720> <not yet classified>
        attachment = instance_variable_get(ivar)

        if attachment.nil?
          attachment = Attachment.new(name, self, options)
          #nodyna <instance_variable_set-721> <not yet classified>
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
      #nodyna <send-722> <SD MODERATE (private methods)>
      #nodyna <define_method-723> <DM COMPLEX (events)>
      @klass.send :define_method, "#{@name}=" do |file|
        #nodyna <send-724> <SD COMPLEX (change-prone variables)>
        send(name).assign(file)
      end
    end

    def define_query
      name = @name
      #nodyna <send-725> <SD MODERATE (private methods)>
      #nodyna <define_method-726> <DM COMPLEX (events)>
      @klass.send :define_method, "#{@name}?" do
        #nodyna <send-727> <SD COMPLEX (change-prone variables)>
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
          #nodyna <send-728> <SD COMPLEX (change-prone variables)>
          :if => ->(instance){ instance.send(name).dirty? }
      end
    end

    def add_active_record_callbacks
      name = @name
      #nodyna <send-729> <SD TRIVIAL (public methods)>
      #nodyna <send-730> <SD COMPLEX (change-prone variables)>
      #nodyna <send-731> <SD TRIVIAL (public methods)>
      @klass.send(:after_save) { send(name).send(:save) }
      #nodyna <send-732> <SD TRIVIAL (public methods)>
      #nodyna <send-733> <SD COMPLEX (change-prone variables)>
      #nodyna <send-734> <SD EASY (private methods)>
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      #nodyna <send-735> <SD TRIVIAL (public methods)>
      #nodyna <send-736> <SD COMPLEX (change-prone variables)>
      #nodyna <send-737> <SD TRIVIAL (public methods)>
      @klass.send(:after_commit, :on => :destroy) { send(name).send(:flush_deletes) }
    end

    def add_paperclip_callbacks
      #nodyna <send-738> <SD TRIVIAL (public methods)>
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
