require 'pathname'

class Pathname
  if RUBY_VERSION == "2.0.0"
    prepend Module.new {
      def inspect
        super.force_encoding(@path.encoding)
      end
    }
  end
end
