require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::xpm')

module Tk
  module Img
    module XPM
      PACKAGE_NAME = 'img::xpm'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::xpm')
        rescue
          ''
        end
      end
    end
  end
end
