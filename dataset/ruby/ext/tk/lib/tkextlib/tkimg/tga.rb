require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::tga')

module Tk
  module Img
    module TGA
      PACKAGE_NAME = 'img::tga'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::tga')
        rescue
          ''
        end
      end
    end
  end
end
