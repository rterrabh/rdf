
require 'tk'
require 'tk/entry'
require 'tkextlib/tcllib.rb'

TkPackage.require('datefield')

module Tk
  module Tcllib
    class Datefield < Tk::Entry
      PACKAGE_NAME = 'datefield'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('datefield')
        rescue
          ''
        end
      end
    end
    DateField = Datefield
  end
end

class Tk::Tcllib::Datefield
  TkCommandNames = ['::datefield::datefield'.freeze].freeze

  def create_self(keys)
    if keys and keys != None
      tk_call_without_enc(self.class::TkCommandNames[0], @path,
                          *hash_kv(keys, true))
    else
      tk_call_without_enc(self.class::TkCommandNames[0], @path)
    end
  end
  private :create_self
end
