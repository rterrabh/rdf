require 'abstract_controller/collector'

module ActionController #:nodoc:
  module MimeResponds
    extend ActiveSupport::Concern

    module ClassMethods
      def respond_to(*)
        raise NoMethodError, "The controller-level `respond_to' feature has " \
          "been extracted to the `responders` gem. Add it to your Gemfile to " \
          "continue using this feature:\n" \
          "  gem 'responders', '~> 2.0'\n" \
          "Consult the Rails upgrade guide for details."
      end
    end

    def respond_with(*)
      raise NoMethodError, "The `respond_with' feature has been extracted " \
        "to the `responders` gem. Add it to your Gemfile to continue using " \
        "this feature:\n" \
        "  gem 'responders', '~> 2.0'\n" \
        "Consult the Rails upgrade guide for details."
    end

    def respond_to(*mimes)
      raise ArgumentError, "respond_to takes either types or a block, never both" if mimes.any? && block_given?

      collector = Collector.new(mimes, request.variant)
      yield collector if block_given?

      if format = collector.negotiate_format(request)
        _process_format(format)
        response = collector.response
        response ? response.call : render({})
      else
        raise ActionController::UnknownFormat
      end
    end

    class Collector
      include AbstractController::Collector
      attr_accessor :format

      def initialize(mimes, variant = nil)
        @responses = {}
        @variant = variant

        mimes.each { |mime| @responses["Mime::#{mime.upcase}".constantize] = nil }
      end

      def any(*args, &block)
        if args.any?
          #nodyna <send-1302> <SD MODERATE (array)>
          args.each { |type| send(type, &block) }
        else
          custom(Mime::ALL, &block)
        end
      end
      alias :all :any

      def custom(mime_type, &block)
        mime_type = Mime::Type.lookup(mime_type.to_s) unless mime_type.is_a?(Mime::Type)
        @responses[mime_type] ||= if block_given?
          block
        else
          VariantCollector.new(@variant)
        end
      end

      def response
        response = @responses.fetch(format, @responses[Mime::ALL])
        if response.is_a?(VariantCollector) # `format.html.phone` - variant inline syntax
          response.variant
        elsif response.nil? || response.arity == 0 # `format.html` - just a format, call its block
          response
        else # `format.html{ |variant| variant.phone }` - variant block syntax
          variant_collector = VariantCollector.new(@variant)
          response.call(variant_collector) # call format block with variants collector
          variant_collector.variant
        end
      end

      def negotiate_format(request)
        @format = request.negotiate_mime(@responses.keys)
      end

      class VariantCollector #:nodoc:
        def initialize(variant = nil)
          @variant = variant
          @variants = {}
        end

        def any(*args, &block)
          if block_given?
            if args.any? && args.none?{ |a| a == @variant }
              args.each{ |v| @variants[v] = block }
            else
              @variants[:any] = block
            end
          end
        end
        alias :all :any

        def method_missing(name, *args, &block)
          @variants[name] = block if block_given?
        end

        def variant
          if @variant.nil?
            @variants[:none] || @variants[:any]
          elsif (@variants.keys & @variant).any?
            @variant.each do |v|
              return @variants[v] if @variants.key?(v)
            end
          else
            @variants[:any]
          end
        end
      end
    end
  end
end
