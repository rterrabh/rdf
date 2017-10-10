require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::sun')

module Tk
  module Img
    module SUN
      PACKAGE_NAME = 'img::sun'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::sun')
        rescue
          ''
        end
      end
    end
  end
end
