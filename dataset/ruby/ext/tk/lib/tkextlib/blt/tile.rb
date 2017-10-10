
require 'tk'
require 'tkextlib/blt.rb'

module Tk::BLT
  module Tile
    TkComm::TkExtlibAutoloadModule.unshift(self)

    autoload :Button,      'tkextlib/blt/tile/button.rb'
    autoload :CheckButton, 'tkextlib/blt/tile/checkbutton.rb'
    autoload :Checkbutton, 'tkextlib/blt/tile/checkbutton.rb'
    autoload :Radiobutton, 'tkextlib/blt/tile/radiobutton.rb'
    autoload :RadioButton, 'tkextlib/blt/tile/radiobutton.rb'
    autoload :Frame,       'tkextlib/blt/tile/frame.rb'
    autoload :Label,       'tkextlib/blt/tile/label.rb'
    autoload :Scrollbar,   'tkextlib/blt/tile/scrollbar.rb'
    autoload :Toplevel,    'tkextlib/blt/tile/toplevel.rb'
  end
end
