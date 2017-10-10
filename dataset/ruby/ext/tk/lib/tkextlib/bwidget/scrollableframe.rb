
require 'tk'
require 'tk/frame'
require 'tkextlib/bwidget.rb'

module Tk
  module BWidget
    class ScrollableFrame < TkWindow
    end
  end
end

class Tk::BWidget::ScrollableFrame
  include Scrollable

  TkCommandNames = ['ScrollableFrame'.freeze].freeze
  WidgetClassName = 'ScrollableFrame'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def get_frame(&b)
    win = window(tk_send_without_enc('getframe'))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1629> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1630> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def see(win, vert=None, horiz=None)
    tk_send_without_enc('see', win, vert, horiz)
    self
  end
end
