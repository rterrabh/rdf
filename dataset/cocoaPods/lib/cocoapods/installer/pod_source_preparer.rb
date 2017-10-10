module Pod
  class Installer
    class PodSourcePreparer
      attr_reader :spec

      attr_reader :path

      def initialize(spec, path)
        raise "Given spec isn't a root spec, but must be." unless spec.root?
        @spec = spec
        @path = path
      end


      public


      def prepare!
        run_prepare_command
      end


      private


      extend Executable
      executable :bash

      def run_prepare_command
        return unless spec.prepare_command
        UI.section(' > Running prepare command', '', 1) do
          Dir.chdir(path) do
            ENV.delete('CDPATH')
            prepare_command = spec.prepare_command.strip_heredoc.chomp
            full_command = "\nset -e\n" + prepare_command
            bash!('-c', full_command)
          end
        end
      end

    end
  end
end
