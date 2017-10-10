require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::gif')

module Tk
  module Img
    module GIF
      PACKAGE_NAME = 'img::gif'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::gif')
        rescue
          ''
        end
      end
    end
  end
end
