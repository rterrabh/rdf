module ActionView #:nodoc:
  class Template
    module Handlers #:nodoc:
      autoload :ERB, 'action_view/template/handlers/erb'
      autoload :Builder, 'action_view/template/handlers/builder'
      autoload :Raw, 'action_view/template/handlers/raw'

      def self.extended(base)
        base.register_default_template_handler :erb, ERB.new
        base.register_template_handler :builder, Builder.new
        base.register_template_handler :raw, Raw.new
        base.register_template_handler :ruby, :source.to_proc
      end

      @@template_handlers = {}
      @@default_template_handlers = nil

      def self.extensions
        @@template_extensions ||= @@template_handlers.keys
      end

      def register_template_handler(*extensions, handler)
        raise(ArgumentError, "Extension is required") if extensions.empty?
        extensions.each do |extension|
          @@template_handlers[extension.to_sym] = handler
        end
        @@template_extensions = nil
      end

      def unregister_template_handler(*extensions)
        extensions.each do |extension|
          handler = @@template_handlers.delete extension.to_sym
          @@default_template_handlers = nil if @@default_template_handlers == handler
        end
        @@template_extensions = nil
      end

      def template_handler_extensions
        @@template_handlers.keys.map {|key| key.to_s }.sort
      end

      def registered_template_handler(extension)
        extension && @@template_handlers[extension.to_sym]
      end

      def register_default_template_handler(extension, klass)
        register_template_handler(extension, klass)
        @@default_template_handlers = klass
      end

      def handler_for_extension(extension)
        registered_template_handler(extension) || @@default_template_handlers
      end
    end
  end
end
