require 'action_view/base'

module ActionView
  module ViewPaths
    extend ActiveSupport::Concern

    included do
      class_attribute :_view_paths
      self._view_paths = ActionView::PathSet.new
      self._view_paths.freeze
    end

    delegate :template_exists?, :view_paths, :formats, :formats=,
             :locale, :locale=, :to => :lookup_context

    module ClassMethods
      def _prefixes # :nodoc:
        @_prefixes ||= begin
          deprecated_prefixes = handle_deprecated_parent_prefixes
          if deprecated_prefixes
            deprecated_prefixes
          else
            return local_prefixes if superclass.abstract?

            local_prefixes + superclass._prefixes
          end
        end
      end

      private

      def local_prefixes
        [controller_path]
      end

      def handle_deprecated_parent_prefixes # TODO: remove in 4.3/5.0.
        return unless respond_to?(:parent_prefixes)

        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Overriding `ActionController::Base::parent_prefixes` is deprecated,
          override `.local_prefixes` instead.
        MSG

        local_prefixes + parent_prefixes
      end
    end

    def _prefixes # :nodoc:
      self.class._prefixes
    end

    def lookup_context
      @_lookup_context ||=
        ActionView::LookupContext.new(self.class._view_paths, details_for_lookup, _prefixes)
    end

    def details_for_lookup
      { }
    end

    def append_view_path(path)
      lookup_context.view_paths.push(*path)
    end

    def prepend_view_path(path)
      lookup_context.view_paths.unshift(*path)
    end

    module ClassMethods
      def append_view_path(path)
        self._view_paths = view_paths + Array(path)
      end

      def prepend_view_path(path)
        self._view_paths = ActionView::PathSet.new(Array(path) + view_paths)
      end

      def view_paths
        _view_paths
      end

      def view_paths=(paths)
        self._view_paths = ActionView::PathSet.new(Array(paths))
      end
    end
  end
end
