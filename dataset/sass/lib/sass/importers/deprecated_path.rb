module Sass
  module Importers
    class DeprecatedPath < Filesystem
      def initialize(root)
        @specified_root = root
        @warning_given = false
        super
      end

      def find(*args)
        found = super
        if found && !@warning_given
          @warning_given = true
          Sass::Util.sass_warn deprecation_warning
        end
        found
      end

      def directories_to_watch
        []
      end

      def to_s
        "#{@root} (DEPRECATED)"
      end

      protected

      def deprecation_warning
        path = @specified_root == "." ? "the current working directory" : @specified_root
        <<WARNING
DEPRECATION WARNING: Importing from #{path} will not be
automatic in future versions of Sass.  To avoid future errors, you can add it
to your environment explicitly by setting `SASS_PATH=#{@specified_root}`, by using the -I command
line option, or by changing your Sass configuration options.
WARNING
      end
    end
  end
end
