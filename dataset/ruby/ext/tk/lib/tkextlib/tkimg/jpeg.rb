require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::jpeg')

module Tk
  module Img
    module JPEG
      PACKAGE_NAME = 'img::jpeg'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::jpeg')
        rescue
          ''
        end
      end
    end
  end
end
