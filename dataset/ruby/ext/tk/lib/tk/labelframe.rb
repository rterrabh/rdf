require 'tk'
require 'tk/frame'

class Tk::LabelFrame<Tk::Frame
  TkCommandNames = ['labelframe'.freeze].freeze
  WidgetClassName = 'Labelframe'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def __val2ruby_optkeys  # { key=>proc, ... }
    super().update('labelwidget'=>proc{|v| window(v)})
  end
  private :__val2ruby_optkeys
end

Tk::Labelframe = Tk::LabelFrame
Tk.__set_loaded_toplevel_aliases__('tk/labelframe.rb', :Tk, Tk::LabelFrame,
                                   :TkLabelFrame, :TkLabelframe)
