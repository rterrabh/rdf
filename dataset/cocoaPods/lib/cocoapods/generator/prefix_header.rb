module Pod
  module Generator
    class PrefixHeader < Header
      attr_reader :file_accessors

      def initialize(file_accessors, platform)
        @file_accessors = file_accessors
        super platform
      end

      def generate
        result = super

        unique_prefix_header_contents = file_accessors.map do |file_accessor|
          file_accessor.spec_consumer.prefix_header_contents
        end.compact.uniq

        unique_prefix_header_contents.each do |prefix_header_contents|
          result << prefix_header_contents
          result << "\n"
        end

        file_accessors.map(&:prefix_header).compact.uniq.each do |prefix_header|
          result << Pathname(prefix_header).read
        end

        result
      end

      protected

      def generate_platform_import_header
        result =  "#ifdef __OBJC__\n"
        result << super
        result << "#endif\n"
      end
    end
  end
end
