module ActiveAdmin
  module Helpers
    module Collection
      def collection_size(c = collection)
        c = c.except :select, :order

        c.group_values.present? ? c.count.count : c.count
      end

      def collection_is_empty?(c = collection)
        collection_size(c) == 0
      end
    end
  end
end
