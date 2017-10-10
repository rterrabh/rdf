module ActiveAdmin
  class Resource
    module ScopeTo

      def scope_to(*args, &block)
        options = args.extract_options!
        method = args.first

        scope_to_config[:method]              = block || method
        scope_to_config[:association_method]  = options[:association_method]
        scope_to_config[:if]                  = options[:if]
        scope_to_config[:unless]              = options[:unless]

      end

      def scope_to_association_method
        scope_to_config[:association_method]
      end

      def scope_to_method
        scope_to_config[:method]
      end

      def scope_to_config
        @scope_to_config ||= {
          method:             nil,
          association_method: nil,
          if:                 nil,
          unless:             nil
        }
      end

      def scope_to?(context = nil)
        return false if scope_to_method.nil?
        return render_in_context(context, scope_to_config[:if]) unless scope_to_config[:if].nil?
        return !render_in_context(context, scope_to_config[:unless]) unless scope_to_config[:unless].nil?
        true
      end

    end
  end
end
