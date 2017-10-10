require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::png')

module Tk
  module Img
    module PNG
      PACKAGE_NAME = 'img::png'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::png')
        rescue
          ''
        end
      end
    end
  end
end
