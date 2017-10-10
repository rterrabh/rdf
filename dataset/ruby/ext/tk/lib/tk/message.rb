require 'tk'
require 'tk/label'

class Tk::Message<Tk::Label
  TkCommandNames = ['message'.freeze].freeze
  WidgetClassName = 'Message'.freeze
  WidgetClassNames[WidgetClassName] ||= self
  private :create_self
end

Tk.__set_loaded_toplevel_aliases__('tk/message.rb', :Tk, Tk::Message,
                                   :TkMessage)
