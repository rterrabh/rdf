
require 'tk'
require 'tk/frame'
require 'tkextlib/bwidget.rb'

module Tk
  module BWidget
    class PanedWindow < TkWindow
    end
  end
end

class Tk::BWidget::PanedWindow
  TkCommandNames = ['PanedWindow'.freeze].freeze
  WidgetClassName = 'PanedWindow'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def __strval_optkeys
    super() << 'activator'
  end
  private :__strval_optkeys

  def add(keys={})
    window(tk_send('add', *hash_kv(keys)))
  end

  def get_frame(idx, &b)
    win = window(tk_send_without_enc('getframe', idx))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1627> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1628> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end
end
