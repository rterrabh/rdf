module RailsAdmin
  module Config
    module HasDescription
      attr_reader :description

      def desc(description, &_block)
        @description ||= description
      end
    end
  end
end
