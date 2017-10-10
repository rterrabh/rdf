require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::xbm')

module Tk
  module Img
    module XBM
      PACKAGE_NAME = 'img::xbm'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::xbm')
        rescue
          ''
        end
      end
    end
  end
end
