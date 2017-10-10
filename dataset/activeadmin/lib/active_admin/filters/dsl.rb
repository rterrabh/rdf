module ActiveAdmin
  module Filters
    module DSL

      def filter(attribute, options = {})
        config.add_filter(attribute, options)
      end

      def remove_filter(*attributes)
        config.remove_filter(*attributes)
      end

      def preserve_default_filters!
        config.preserve_default_filters!
      end
    end
  end
end
