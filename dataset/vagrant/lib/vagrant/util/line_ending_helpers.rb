module Vagrant
  module Util
    module LineEndingHelpers
      def dos_to_unix(string)
        string.gsub("\r\n", "\n")
      end
    end
  end
end
