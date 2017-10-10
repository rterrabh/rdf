
require 'tk'
require 'tkextlib/bwidget.rb'

module Tk
  module BWidget
    class ProgressBar < TkWindow
    end
  end
end

class Tk::BWidget::ProgressBar
  TkCommandNames = ['ProgressBar'.freeze].freeze
  WidgetClassName = 'ProgressBar'.freeze
  WidgetClassNames[WidgetClassName] ||= self
end
