
require 'tk'
require 'tkextlib/tcllib.rb'

TkPackage.require('khim')

module Tk::Tcllib
  class KHIM < TkToplevel
    PACKAGE_NAME = 'khim'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('khim')
      rescue
        ''
      end
    end
  end
end

class Tk::Tcllib::KHIM
  TkCommandNames = ['::khim::getOptions'.freeze].freeze

  def self.get_options(parent='')
    path = parent + '.tcllib_widget_khim_dialog'
    self.new(:widgetname => path)
  end

  def self.get_config #=> cmd_string
    Tk.tk_call_without_enc('::khim::getConfig')
  end

  def self.set_config(*args)
    if args.length == 1
      Tk.ip_eval(cmd_string)
    else
      Tk.tk_call('::khim::setConfig', *args)
    end
  end

  def self.showHelp
    Tk::Tcllib::KHIM::Help.new
  end

  def create_self(keys=None)
    @db_class = @classname = nil
    super(None) # ignore keys
  end
end

class Tk::Tcllib::KHIM::Help < TkToplevel
  TkCommandNames = ['::khim::showHelp'.freeze].freeze
end
