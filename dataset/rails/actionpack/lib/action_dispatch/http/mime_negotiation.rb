require 'active_support/core_ext/module/attribute_accessors'

module ActionDispatch
  module Http
    module MimeNegotiation
      extend ActiveSupport::Concern

      included do
        mattr_accessor :ignore_accept_header
        self.ignore_accept_header = false
      end

      attr_reader :variant

      def content_mime_type
        @env["action_dispatch.request.content_type"] ||= begin
          if @env['CONTENT_TYPE'] =~ /^([^,\;]*)/
            Mime::Type.lookup($1.strip.downcase)
          else
            nil
          end
        end
      end

      def content_type
        content_mime_type && content_mime_type.to_s
      end

      def accepts
        @env["action_dispatch.request.accepts"] ||= begin
          header = @env['HTTP_ACCEPT'].to_s.strip

          if header.empty?
            [content_mime_type]
          else
            Mime::Type.parse(header)
          end
        end
      end

      def format(view_path = [])
        formats.first || Mime::NullType.instance
      end

      def formats
        @env["action_dispatch.request.formats"] ||= begin
          params_readable = begin
                              parameters[:format]
                            rescue ActionController::BadRequest
                              false
                            end

          if params_readable
            Array(Mime[parameters[:format]])
          elsif use_accept_header && valid_accept_header
            accepts
          elsif xhr?
            [Mime::JS]
          else
            [Mime::HTML]
          end
        end
      end

      def variant=(variant)
        if variant.is_a?(Symbol)
          @variant = [variant]
        elsif variant.nil? || variant.is_a?(Array) && variant.any? && variant.all?{ |v| v.is_a?(Symbol) }
          @variant = variant
        else
          raise ArgumentError, "request.variant must be set to a Symbol or an Array of Symbols, not a #{variant.class}. " \
            "For security reasons, never directly set the variant to a user-provided value, " \
            "like params[:variant].to_sym. Check user-provided value against a whitelist first, " \
            "then set the variant: request.variant = :tablet if params[:variant] == 'tablet'"
        end
      end

      def format=(extension)
        parameters[:format] = extension.to_s
        @env["action_dispatch.request.formats"] = [Mime::Type.lookup_by_extension(parameters[:format])]
      end

      def formats=(extensions)
        parameters[:format] = extensions.first.to_s
        @env["action_dispatch.request.formats"] = extensions.collect do |extension|
          Mime::Type.lookup_by_extension(extension)
        end
      end

      def negotiate_mime(order)
        formats.each do |priority|
          if priority == Mime::ALL
            return order.first
          elsif order.include?(priority)
            return priority
          end
        end

        order.include?(Mime::ALL) ? format : nil
      end

      protected

      BROWSER_LIKE_ACCEPTS = /,\s*\*\/\*|\*\/\*\s*,/

      def valid_accept_header
        (xhr? && (accept.present? || content_mime_type)) ||
          (accept.present? && accept !~ BROWSER_LIKE_ACCEPTS)
      end

      def use_accept_header
        !self.class.ignore_accept_header
      end
    end
  end
end
