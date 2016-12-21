#
#  tkextlib/bwidget/scrollableframe.rb
#                               by Hidetoshi NAGAI (nagai@ai.kyutech.ac.jp)
#

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
        #nodyna <ID:instance_exec-14> <instance_exec VERY HIGH ex2>
        win.instance_exec(self, &b)
      else
        #nodyna <ID:instance_eval-115> <instance_eval VERY HIGH ex3>
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
