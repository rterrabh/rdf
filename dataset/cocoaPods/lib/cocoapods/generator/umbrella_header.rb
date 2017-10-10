module Pod
  module Generator
    class UmbrellaHeader < Header
      attr_reader :target

      def initialize(target)
        super(target.platform)
        @target = target
      end

      def generate
        result = super

        result << "\n"

        result << <<-eos.strip_heredoc
        FOUNDATION_EXPORT double #{target.product_module_name}VersionNumber;
        FOUNDATION_EXPORT const unsigned char #{target.product_module_name}VersionString[];
        eos

        result << "\n"

        result
      end
    end
  end
end
