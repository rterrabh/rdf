require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::dted')

module Tk
  module Img
    module DTED
      PACKAGE_NAME = 'img::dted'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::dted')
        rescue
          ''
        end
      end
    end
  end
end
