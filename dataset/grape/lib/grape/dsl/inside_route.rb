require 'active_support/concern'

module Grape
  module DSL
    module InsideRoute
      extend ActiveSupport::Concern
      include Grape::DSL::Settings

      def declared(params, options = {}, declared_params = nil)
        options[:include_missing] = true unless options.key?(:include_missing)
        options[:include_parent_namespaces] = true unless options.key?(:include_parent_namespaces)

        if declared_params.nil?
          declared_params = (!options[:include_parent_namespaces] ? route_setting(:declared_params) :
              (route_setting(:saved_declared_params) || [])).flatten(1) || []
        end

        unless declared_params
          fail ArgumentError, 'Tried to filter for declared parameters but none exist.'
        end

        if params.is_a? Array
          params.map do |param|
            declared(param || {}, options, declared_params)
          end
        else
          declared_params.inject(Hashie::Mash.new) do |hash, key|
            key = { key => nil } unless key.is_a? Hash

            key.each_pair do |parent, children|
              output_key = options[:stringify] ? parent.to_s : parent.to_sym

              next unless options[:include_missing] || params.key?(parent)

              hash[output_key] = if children
                                   children_params = params[parent] || (children.is_a?(Array) ? [] : {})
                                   declared(children_params, options, Array(children))
                                 else
                                   params[parent]
                                 end
            end

            hash
          end
        end
      end

      def version
        env['api.version']
      end

      def error!(message, status = nil, headers = nil)
        self.status(status || namespace_inheritable(:default_error_status))
        throw :error, message: message, status: self.status, headers: headers
      end

      def redirect(url, options = {})
        merged_options = { permanent: false }.merge(options)
        if merged_options[:permanent]
          status 301
        else
          if env[Grape::Http::Headers::HTTP_VERSION] == 'HTTP/1.1' && request.request_method.to_s.upcase != Grape::Http::Headers::GET
            status 303
          else
            status 302
          end
        end
        header 'Location', url
        body ''
      end

      def status(status = nil)
        case status
        when Symbol
          if Rack::Utils::SYMBOL_TO_STATUS_CODE.keys.include?(status)
            @status = Rack::Utils.status_code(status)
          else
            fail ArgumentError, "Status code :#{status} is invalid."
          end
        when Fixnum
          @status = status
        when nil
          return @status if @status
          case request.request_method.to_s.upcase
          when Grape::Http::Headers::POST
            201
          else
            200
          end
        else
          fail ArgumentError, 'Status code must be Fixnum or Symbol.'
        end
      end

      def header(key = nil, val = nil)
        if key
          val ? @header[key.to_s] = val : @header.delete(key.to_s)
        else
          @header
        end
      end

      def content_type(val = nil)
        if val
          header(Grape::Http::Headers::CONTENT_TYPE, val)
        else
          header[Grape::Http::Headers::CONTENT_TYPE]
        end
      end

      def cookies
        @cookies ||= Cookies.new
      end

      def body(value = nil)
        if value
          @body = value
        elsif value == false
          @body = ''
          status 204
        else
          @body
        end
      end

      def file(value = nil)
        if value
          @file = Grape::Util::FileResponse.new(value)
        else
          @file
        end
      end

      def stream(value = nil)
        header 'Content-Length', nil
        header 'Transfer-Encoding', nil
        header 'Cache-Control', 'no-cache' # Skips ETag generation (reading the response up front)
        file(value)
      end

      def present(*args)
        options = args.count > 1 ? args.extract_options! : {}
        key, object = if args.count == 2 && args.first.is_a?(Symbol)
                        args
                      else
                        [nil, args.first]
                      end
        entity_class = entity_class_for_obj(object, options)

        root = options.delete(:root)

        representation = if entity_class
                           entity_representation_for(entity_class, object, options)
                         else
                           object
                         end

        representation = { root => representation } if root
        if key
          representation = (@body || {}).merge(key => representation)
        elsif entity_class.present? && @body
          fail ArgumentError, "Representation of type #{representation.class} cannot be merged." unless representation.respond_to?('merge')
          representation = @body.merge(representation)
        end

        body representation
      end

      def route
        env['rack.routing_args'][:route_info]
      end

      def entity_class_for_obj(object, options)
        entity_class = options.delete(:with)

        if entity_class.nil?
          object_class = if object.respond_to?(:klass)
                           object.klass
                         else
                           object.respond_to?(:first) ? object.first.class : object.class
                         end

          object_class.ancestors.each do |potential|
            entity_class ||= (Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:representations)) || {})[potential]
          end

          #nodyna <const_get-2813> <not yet classified>
          #nodyna <const_get-2814> <not yet classified>
          entity_class ||= object_class.const_get(:Entity) if object_class.const_defined?(:Entity) && object_class.const_get(:Entity).respond_to?(:represent)
        end

        entity_class
      end

      def entity_representation_for(entity_class, object, options)
        embeds = { env: env }
        embeds[:version] = env['api.version'] if env['api.version']
        entity_class.represent(object, embeds.merge(options))
      end
    end
  end
end
