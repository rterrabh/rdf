
require 'tk'
require 'tkextlib/iwidgets.rb'

module Tk
  module Iwidgets
    class Scrolledwidget < Tk::Iwidgets::Labeledwidget
    end
  end
end

class Tk::Iwidgets::Scrolledwidget
  TkCommandNames = ['::iwidgets::scrolledwidget'.freeze].freeze
  WidgetClassName = 'Scrolledwidget'.freeze
  WidgetClassNames[WidgetClassName] ||= self
end
