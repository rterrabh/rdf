
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::pcx')

module Tk
  module Img
    module PCX
      PACKAGE_NAME = 'img::pcx'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::pcx')
        rescue
          ''
        end
      end
    end
  end
end
