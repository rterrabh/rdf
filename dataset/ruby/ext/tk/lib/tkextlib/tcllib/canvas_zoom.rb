
require 'tk'
require 'tkextlib/tcllib.rb'

TkPackage.require('widget::canvas_zoom')

module Tk::Tcllib
  module Widget
    class Canvas_Zoom < Canvas
      TkCommandNames = ['::widget::canvas_zoom'.freeze].freeze
    end
  end
end
