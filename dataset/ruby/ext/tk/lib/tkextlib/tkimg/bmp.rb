require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::bmp')

module Tk
  module Img
    module BMP
      PACKAGE_NAME = 'img::bmp'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::bmp')
        rescue
          ''
        end
      end
    end
  end
end
