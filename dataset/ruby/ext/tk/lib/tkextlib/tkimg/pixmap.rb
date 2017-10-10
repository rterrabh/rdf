require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::pixmap')

module Tk
  module Img
    module PIXMAP
      PACKAGE_NAME = 'img::pixmap'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::pixmap')
        rescue
          ''
        end
      end
    end
  end
end

class TkPixmapImage<TkImage
  def self.version
    Tk::Img::PIXMAP.version
  end

  def initialize(*args)
    @type = 'pixmap'
    super(*args)
  end
end
