require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::sgi')

module Tk
  module Img
    module SGI
      PACKAGE_NAME = 'img::sgi'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::sgi')
        rescue
          ''
        end
      end
    end
  end
end
