module ActiveAdmin

  class Resource
    module Pagination

      attr_accessor :per_page

      attr_accessor :paginate

      def initialize(*args)
        super
        @paginate = true
        @per_page = namespace.default_per_page
      end
    end
  end
end
