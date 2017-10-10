
require 'tk'
require 'tk/frame'
require 'tkextlib/bwidget.rb'

module Tk
  module BWidget
    class TitleFrame < TkWindow
    end
  end
end

class Tk::BWidget::TitleFrame
  TkCommandNames = ['TitleFrame'.freeze].freeze
  WidgetClassName = 'TitleFrame'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def get_frame(&b)
    win = window(tk_send_without_enc('getframe'))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1602> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1603> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end
end
