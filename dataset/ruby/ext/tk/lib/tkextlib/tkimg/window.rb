require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::window')

module Tk
  module Img
    module WINDOW
      PACKAGE_NAME = 'img::window'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::window')
        rescue
          ''
        end
      end
    end
  end
end
