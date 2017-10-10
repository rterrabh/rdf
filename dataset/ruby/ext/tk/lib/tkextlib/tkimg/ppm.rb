require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::ppm')

module Tk
  module Img
    module PPM
      PACKAGE_NAME = 'img::ppm'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::ppm')
        rescue
          ''
        end
      end
    end
  end
end
