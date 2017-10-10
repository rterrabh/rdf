
require 'tk'
require 'tk/frame'
require 'tkextlib/bwidget.rb'
require 'tkextlib/bwidget/progressbar'

module Tk
  module BWidget
    class MainFrame < TkWindow
    end
  end
end

class Tk::BWidget::MainFrame
  TkCommandNames = ['MainFrame'.freeze].freeze
  WidgetClassName = 'MainFrame'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def __strval_optkeys
    super() << 'progressfg'
  end
  private :__strval_optkeys

  def __tkvariable_optkeys
    super() << 'progressvar'
  end
  private :__tkvariable_optkeys

  def __val2ruby_optkeys  # { key=>proc, ... }
    {
      'menu'=>proc{|v| simplelist(v).collect!{|elem| simplelist(v)}}
    }
  end
  private :__val2ruby_optkeys

  def add_indicator(keys={}, &b)
    win = window(tk_send('addindicator', *hash_kv(keys)))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1590> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1591> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def add_toolbar(&b)
    win = window(tk_send('addtoolbar'))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1592> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1593> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def get_frame(&b)
    win = window(tk_send('getframe'))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1594> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1595> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def get_indicator(idx, &b)
    win = window(tk_send('getindicator', idx))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1596> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1597> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def get_menu(menu_id, &b)
    win = window(tk_send('getmenu', menu_id))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1598> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1599> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def get_toolbar(idx, &b)
    win = window(tk_send('gettoolbar', idx))
    if b
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1600> <IEX COMPLEX (block with parameters)>
        win.instance_exec(self, &b)
      else
        #nodyna <instance_eval-1601> <IEV COMPLEX (block execution)>
        win.instance_eval(&b)
      end
    end
    win
  end

  def get_menustate(tag)
    tk_send('getmenustate', tag) # return state name string
  end

  def set_menustate(tag, state)
    tk_send('setmenustate', tag, state)
    self
  end

  def show_statusbar(name)
    tk_send('showstatusbar', name)
    self
  end

  def show_toolbar(idx, mode)
    tk_send('showtoolbar', idx, mode)
    self
  end
end
