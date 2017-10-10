require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::raw')

module Tk
  module Img
    module Raw
      PACKAGE_NAME = 'img::raw'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::raw')
        rescue
          ''
        end
      end
    end
  end
end
