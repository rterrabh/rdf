
require 'tk'
require 'tk/button'
require 'tkextlib/blt/tile.rb'

module Tk::BLT
  module Tile
    class Button < Tk::Button
      TkCommandNames = ['::blt::tile::button'.freeze].freeze
    end
  end
end
