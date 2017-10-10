module ActiveAdmin
  class Resource
    module Includes

      def includes
        @includes ||= []
      end

    end
  end
end
