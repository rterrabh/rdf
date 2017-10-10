module Pod
  module Generator
    class ModuleMap
      attr_reader :target

      attr_accessor :private_headers

      def initialize(target)
        @target = target
        @private_headers = []
      end

      def save_as(path)
        contents = generate
        path.open('w') do |f|
          f.write(contents)
        end
      end

      def generate
        result = <<-eos.strip_heredoc
          framework module #{target.product_module_name} {
            umbrella header "#{target.umbrella_header_path.basename}"

            export *
            module * { export * }
        eos

        result << "\n#{generate_private_header_exports}" unless private_headers.empty?
        result << "}\n"
      end

      private

      def generate_private_header_exports
        private_headers.reduce('') do |string, header|
          string << %(  private header "#{header}"\n)
        end
      end
    end
  end
end
