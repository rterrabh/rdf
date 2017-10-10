
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('Img')

module Tk
  module Img
    PACKAGE_NAME = 'Img'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('Img')
      rescue
        ''
      end
    end
  end
end

autoload :TkPixmapImage, 'tkextlib/tkimg/pixmap'
