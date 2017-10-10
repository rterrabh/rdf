module ActionView
  module Helpers
    module CacheHelper
      def cache(name = {}, options = nil, &block)
        if controller.respond_to?(:perform_caching) && controller.perform_caching
          safe_concat(fragment_for(cache_fragment_name(name, options), options, &block))
        else
          yield
        end

        nil
      end

      def cache_if(condition, name = {}, options = nil, &block)
        if condition
          cache(name, options, &block)
        else
          yield
        end

        nil
      end

      def cache_unless(condition, name = {}, options = nil, &block)
        cache_if !condition, name, options, &block
      end

      def cache_fragment_name(name = {}, options = nil)
        skip_digest = options && options[:skip_digest]

        if skip_digest
          name
        else
          fragment_name_with_digest(name)
        end
      end

    private

      def fragment_name_with_digest(name) #:nodoc:
        if @virtual_path
          names  = Array(name.is_a?(Hash) ? controller.url_for(name).split("://").last : name)
          digest = Digestor.digest name: @virtual_path, finder: lookup_context, dependencies: view_cache_dependencies

          [ *names, digest ]
        else
          name
        end
      end

      def fragment_for(name = {}, options = nil, &block) #:nodoc:
        read_fragment_for(name, options) || write_fragment_for(name, options, &block)
      end

      def read_fragment_for(name, options) #:nodoc:
        controller.read_fragment(name, options)
      end

      def write_fragment_for(name, options) #:nodoc:
        pos = output_buffer.length
        yield
        output_safe = output_buffer.html_safe?
        fragment = output_buffer.slice!(pos..-1)
        if output_safe
          self.output_buffer = output_buffer.class.new(output_buffer)
        end
        controller.write_fragment(name, fragment, options)
      end
    end
  end
end
