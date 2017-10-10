
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/vu/setup.rb'

TkPackage.require('vu')

module Tk
  module Vu
    TkComm::TkExtlibAutoloadModule.unshift(self)

    PACKAGE_NAME = 'vu'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('vu')
      rescue
        ''
      end
    end


    autoload :Dial,          'tkextlib/vu/dial'

    autoload :Pie,           'tkextlib/vu/pie'
    autoload :PieSlice,      'tkextlib/vu/pie'
    autoload :NamedPieSlice, 'tkextlib/vu/pie'

    autoload :Spinbox,       'tkextlib/vu/spinbox'

    autoload :Bargraph,      'tkextlib/vu/bargraph'
  end
end
