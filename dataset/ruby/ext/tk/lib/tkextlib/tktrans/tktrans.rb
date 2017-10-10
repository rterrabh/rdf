require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tktrans/setup.rb'

TkPackage.require('tktrans') rescue Tk.load_tcllibrary('tktrans')

module Tk
  module TkTrans
    PACKAGE_NAME = 'tktrans'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('tktrans')
      rescue
        ''
      end
    end
  end
end

class TkWindow
  def tktrans_set_image(img)
    tk_send('tktrans::setwidget', @path, img)
    self
  end
  def tktrans_get_image()
    tk_send('tktrans::setwidget', @path)
  end
end

class Tk::Root
  undef tktrans_set_image, tktrans_get_image

  def tktrans_set_image(img)
    tk_send('tktrans::settoplevel', @path, img)
    self
  end
  def tktrans_get_image()
    tk_send('tktrans::settoplevel', @path)
  end
end

class Tk::Toplevel
  undef tktrans_set_image, tktrans_get_image

  def tktrans_set_image(img)
    tk_send('tktrans::settoplevel', @path, img)
    self
  end
  def tktrans_get_image()
    tk_send('tktrans::settoplevel', @path)
  end
end
