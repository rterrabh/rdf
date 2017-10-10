require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::ico')

module Tk
  module Img
    module ICO
      PACKAGE_NAME = 'img::ico'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::ico')
        rescue
          ''
        end
      end
    end
  end
end
