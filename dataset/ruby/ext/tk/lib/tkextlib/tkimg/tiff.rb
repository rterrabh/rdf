require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::tiff')

module Tk
  module Img
    module TIFF
      PACKAGE_NAME = 'img::tiff'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::tiff')
        rescue
          ''
        end
      end
    end
  end
end
