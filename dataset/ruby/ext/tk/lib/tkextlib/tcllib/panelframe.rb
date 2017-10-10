
require 'tk'
require 'tkextlib/tcllib.rb'

TkPackage.require('widget::panelframe')

module Tk::Tcllib
  module Widget
    class PanelFrame < TkWindow
      PACKAGE_NAME = 'widget::panelframe'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('widget::panelframe')
        rescue
          ''
        end
      end
    end
    Panelframe = PanelFrame
  end
end

class Tk::Tcllib::Widget::PanelFrame
  TkCommandNames = ['::widget::panelframe'.freeze].freeze

  def create_self(keys)
    if keys and keys != None
      tk_call_without_enc(self.class::TkCommandNames[0], @path,
                          *hash_kv(keys, true))
    else
      tk_call_without_enc(self.class::TkCommandNames[0], @path)
    end
  end
  private :create_self

  def add(what, *args)
    window(tk_send('add', *args))
  end


  def set_widget(widget)
    tk_send('setwidget', widget)
    self
  end

  def remove(*wins)
    tk_send('remove', *wins)
    self
  end
  def remove_destroy(*wins)
    tk_send('remove', '-destroy', *wins)
    self
  end

  def delete(*wins)
    tk_send('delete', *wins)
    self
  end

  def items
    simplelist(tk_send('items')).collect!{|w| window(w)}
  end
end
