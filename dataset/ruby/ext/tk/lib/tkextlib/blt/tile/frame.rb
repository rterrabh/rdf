
require 'tk'
require 'tk/frame'
require 'tkextlib/blt/tile.rb'

module Tk::BLT
  module Tile
    class Frame < Tk::Frame
      TkCommandNames = ['::blt::tile::frame'.freeze].freeze
    end
  end
end
