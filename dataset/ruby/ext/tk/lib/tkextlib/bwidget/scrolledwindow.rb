#
#  tkextlib/bwidget/scrolledwindow.rb
#                               by Hidetoshi NAGAI (nagai@ai.kyutech.ac.jp)
#

require 'tk'
require 'tk/frame'
require 'tkextlib/bwidget.rb'

module Tk
  module BWidget
    class ScrolledWindow < TkWindow
    end
  end
end

class Tk::BWidget::ScrolledWindow
  TkCommandNames = ['ScrolledWindow'.freeze].freeze
  WidgetClassName = 'ScrolledWindow'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def __strval_optkeys
    super() << 'sides'
  end
  private :__strval_optkeys

  def __boolval_optkeys
    super() << 'managed'
  end
  private :__boolval_optkeys

  def get_frame(&b)
    win = window(tk_send_without_enc('getframe'))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <ID:instance_exec-13> <instance_exec VERY HIGH ex2>
        win.instance_exec(self, &b)
      else
        #nodyna <ID:instance_eval-114> <instance_eval VERY HIGH ex3>
        win.instance_eval(&b)
      end
    end
    win
  end

  def set_widget(win)
    tk_send_without_enc('setwidget', win)
    self
  end
end
