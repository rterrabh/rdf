require 'tk'

class Tk::Label<TkWindow
  TkCommandNames = ['label'.freeze].freeze
  WidgetClassName = 'Label'.freeze
  WidgetClassNames[WidgetClassName] ||= self
end

Tk.__set_loaded_toplevel_aliases__('tk/label.rb', :Tk, Tk::Label, :TkLabel)
