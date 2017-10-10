module Pod
  class Installer
    class SourceProviderHooksContext
      attr_reader :sources

      def self.generate
        result = new
        result
      end

      def initialize
        @sources = []
      end

      def add_source(source)
        unless source.nil?
          @sources << source
        end
      end
    end
  end
end
