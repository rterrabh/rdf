module Vagrant
  module Util
    class FileMode
      def self.from_octal(octal)
        perms = sprintf("%o", octal)
        perms.reverse[0..2].reverse
      end
    end
  end
end
