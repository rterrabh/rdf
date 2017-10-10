
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/trofs/setup.rb'

TkPackage.require('trofs')

module Tk
  module Trofs
    extend TkCore

    PACKAGE_NAME = 'trofs'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('trofs')
      rescue
        ''
      end
    end


    def self.create_archive(dir, archive)
      tk_call('::trofs::archive', dir, archive)
      archive
    end

    def self.mount(archive, mountpoint=None)
      tk_call('::trofs::mount', archive, mountpoint)
    end

    def self.umount(mountpoint)
      tk_call('::trofs::umount', mountpoint)
      mountpoint
    end
  end
end
