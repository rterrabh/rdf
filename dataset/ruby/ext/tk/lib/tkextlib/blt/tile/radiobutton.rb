
require 'tk'
require 'tk/radiobutton'
require 'tkextlib/blt/tile.rb'

module Tk::BLT
  module Tile
    class RadioButton < Tk::RadioButton
      TkCommandNames = ['::blt::tile::radiobutton'.freeze].freeze
    end
    Radiobutton = RadioButton
  end
end
