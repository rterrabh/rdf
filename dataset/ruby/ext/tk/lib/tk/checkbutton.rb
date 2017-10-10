require 'tk'
require 'tk/radiobutton'

class Tk::CheckButton<Tk::RadioButton
  TkCommandNames = ['checkbutton'.freeze].freeze
  WidgetClassName = 'Checkbutton'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def toggle
    tk_send_without_enc('toggle')
    self
  end
end

Tk::Checkbutton = Tk::CheckButton
Tk.__set_loaded_toplevel_aliases__('tk/checkbutton.rb', :Tk, Tk::CheckButton,
                                   :TkCheckButton, :TkCheckbutton)
