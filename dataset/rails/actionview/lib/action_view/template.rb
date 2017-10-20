require 'active_support/core_ext/object/try'
require 'active_support/core_ext/kernel/singleton_class'
require 'thread'

module ActionView
  class Template
    extend ActiveSupport::Autoload


    eager_autoload do
      autoload :Error
      autoload :Handlers
      autoload :HTML
      autoload :Text
      autoload :Types
    end

    extend Template::Handlers

    attr_accessor :locals, :formats, :variants, :virtual_path

    attr_reader :source, :identifier, :handler, :original_encoding, :updated_at

    Finalizer = proc do |method_name, mod|
      proc do
        #nodyna <module_eval-1208> <ME COMPLEX (block execution)>
        mod.module_eval do
          remove_possible_method method_name
        end
      end
    end

    def initialize(source, identifier, handler, details)
      format = details[:format] || (handler.default_format if handler.respond_to?(:default_format))

      @source            = source
      @identifier        = identifier
      @handler           = handler
      @compiled          = false
      @original_encoding = nil
      @locals            = details[:locals] || []
      @virtual_path      = details[:virtual_path]
      @updated_at        = details[:updated_at] || Time.now
      @formats           = Array(format).map { |f| f.respond_to?(:ref) ? f.ref : f  }
      @variants          = [details[:variant]]
      @compile_mutex     = Mutex.new
    end

    def supports_streaming?
      handler.respond_to?(:supports_streaming?) && handler.supports_streaming?
    end

    def render(view, locals, buffer=nil, &block)
      instrument("!render_template") do
        compile!(view)
        #nodyna <send-1209> <SD COMPLEX (change-prone variables)>
        view.send(method_name, locals, buffer, &block)
      end
    rescue => e
      handle_render_error(view, e)
    end

    def type
      @type ||= Types[@formats.first] if @formats.first
    end

    def refresh(view)
      raise "A template needs to have a virtual path in order to be refreshed" unless @virtual_path
      lookup  = view.lookup_context
      pieces  = @virtual_path.split("/")
      name    = pieces.pop
      partial = !!name.sub!(/^_/, "")
      lookup.disable_cache do
        lookup.find_template(name, [ pieces.join('/') ], partial, @locals)
      end
    end

    def inspect
      @inspect ||= defined?(Rails.root) ? identifier.sub("#{Rails.root}/", '') : identifier
    end

    def encode!
      return unless source.encoding == Encoding::BINARY

      if source.sub!(/\A#{ENCODING_FLAG}/, '')
        encoding = magic_encoding = $1
      else
        encoding = Encoding.default_external
      end

      source.force_encoding(encoding)

      if !magic_encoding && @handler.respond_to?(:handles_encoding?) && @handler.handles_encoding?
        source
      elsif source.valid_encoding?
        source.encode!
      else
        raise WrongEncodingError.new(source, encoding)
      end
    end

    protected

      def compile!(view) #:nodoc:
        return if @compiled

        @compile_mutex.synchronize do
          return if @compiled

          if view.is_a?(ActionView::CompiledTemplates)
            mod = ActionView::CompiledTemplates
          else
            mod = view.singleton_class
          end

          instrument("!compile_template") do
            compile(mod)
          end

          @source = nil if @virtual_path
          @compiled = true
        end
      end

      def compile(mod) #:nodoc:
        encode!
        method_name = self.method_name
        code = @handler.call(self)

        source = <<-end_src
          def #{method_name}(local_assigns, output_buffer)
            _old_virtual_path, @virtual_path = @virtual_path, #{@virtual_path.inspect};_old_output_buffer = @output_buffer;#{locals_code};#{code}
          ensure
            @virtual_path, @output_buffer = _old_virtual_path, _old_output_buffer
          end
        end_src

        source.force_encoding(code.encoding)

        source.encode!

        unless source.valid_encoding?
          raise WrongEncodingError.new(@source, Encoding.default_internal)
        end

        #nodyna <module_eval-1210> <ME COMPLEX (define methods)>
        mod.module_eval(source, identifier, 0)
        ObjectSpace.define_finalizer(self, Finalizer[method_name, mod])
      end

      def handle_render_error(view, e) #:nodoc:
        if e.is_a?(Template::Error)
          e.sub_template_of(self)
          raise e
        else
          template = self
          unless template.source
            template = refresh(view)
            template.encode!
          end
          raise Template::Error.new(template, e)
        end
      end

      def locals_code #:nodoc:
        @locals.each_with_object('') { |key, code| code << "#{key} = #{key} = local_assigns[:#{key}];" }
      end

      def method_name #:nodoc:
        @method_name ||= begin
          m = "_#{identifier_method_name}__#{@identifier.hash}_#{__id__}"
          m.tr!('-', '_')
          m
        end
      end

      def identifier_method_name #:nodoc:
        inspect.tr('^a-z_', '_')
      end

      def instrument(action, &block)
        payload = { virtual_path: @virtual_path, identifier: @identifier }
        ActiveSupport::Notifications.instrument("#{action}.action_view", payload, &block)
      end
  end
end
