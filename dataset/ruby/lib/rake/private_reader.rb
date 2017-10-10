module Rake

  module PrivateReader           # :nodoc: all

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def private_reader(*names)
        attr_reader(*names)
        private(*names)
      end
    end

  end
end
