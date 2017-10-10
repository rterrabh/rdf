require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkimg/setup.rb'

TkPackage.require('img::ps')

module Tk
  module Img
    module PS
      PACKAGE_NAME = 'img::ps'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('img::ps')
        rescue
          ''
        end
      end
    end
  end
end
