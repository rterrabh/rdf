require 'tk'
require 'tk/label'

class Tk::Button<Tk::Label
  TkCommandNames = ['button'.freeze].freeze
  WidgetClassName = 'Button'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def invoke
    _fromUTF8(tk_send_without_enc('invoke'))
  end
  def flash
    tk_send_without_enc('flash')
    self
  end
end

Tk.__set_loaded_toplevel_aliases__('tk/button.rb', :Tk, Tk::Button, :TkButton)
