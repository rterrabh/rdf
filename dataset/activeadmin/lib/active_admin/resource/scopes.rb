module ActiveAdmin
  class Resource
    module Scopes

      def scopes
        @scopes ||= []
      end

      def get_scope_by_id(id)
        id = id.to_s
        scopes.find{|s| s.id == id }
      end

      def default_scope(context = nil)
        scopes.detect do |scope|
          if scope.default_block.is_a?(Proc)
            render_in_context(context, scope.default_block)
          else
            scope.default_block
          end
        end
      end

      def scope(*args, &block)
        options = args.extract_options!
        title = args[0] rescue nil
        method = args[1] rescue nil

        scope = ActiveAdmin::Scope.new(title, method, options, &block)

        existing_scope_index = scopes.index{|existing_scope| existing_scope.id == scope.id }
        if existing_scope_index
          scopes.delete_at(existing_scope_index)
          scopes.insert(existing_scope_index, scope)
        else
          self.scopes << scope
        end

        scope
      end

    end
  end
end
