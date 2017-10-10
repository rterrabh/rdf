module Grape
  module Util
    class FileResponse
      attr_reader :file

      def initialize(file)
        @file = file
      end

      def ==(other)
        file == other.file
      end
    end
  end
end
